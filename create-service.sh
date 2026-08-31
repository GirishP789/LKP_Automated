#!/bin/bash
# loc is lkp_directory
loc=$1 
lkp_dir=$2

# Define the script location
LKP_SCRIPT="/var/lib/auto_lkp.sh"

# Create the script file and add the shebang
echo "#!/bin/bash" > "$LKP_SCRIPT"

# Add error handling
echo "set -euo pipefail" >> "$LKP_SCRIPT"

# Define constants
cat <<'EOF' >> "$LKP_SCRIPT"
readonly RESULT_DIR="/lkp/result"

# Verify required directories exist
for dir in "${RESULT_DIR}" "/tmp"; do
    if [[ ! -d "$dir" ]]; then
        echo "Error: Required directory $dir does not exist" >&2
        exit 1
    fi
done

# Verify lkp command exists
if ! command -v lkp >/dev/null 2>&1; then
    echo "Error: 'lkp' command not found" >&2
    exit 1
fi
EOF

# Start the test cases array
echo "test_cases=(" >> "$LKP_SCRIPT"

# Collect test case files
files=$(ls "$lkp_dir/splits/")
file_array=($files)

# Only real jobfiles (*.yaml) are valid arguments to "lkp run". Without this
# filter, non-yaml entries that "lkp" itself drops into splits/ during a run
# (e.g. a "result" symlink to the latest output dir, which can end up
# dangling) get globbed into the array too. "lkp run" then exits non-zero on
# that entry and, since this whole script runs under "set -euo pipefail",
# aborts the entire service before any test cases execute.

# Append test cases starting with 'h' first
for test_case in "${file_array[@]}"
do
    if [[ $test_case == h*.yaml ]]; then
        echo "    \"lkp run $lkp_dir/splits/$test_case\"" >> "$LKP_SCRIPT"
    fi
done

# Append test cases starting with 'e' second
for test_case in "${file_array[@]}"
do
    if [[ $test_case == e*.yaml ]]; then
        echo "    \"lkp run $lkp_dir/splits/$test_case\"" >> "$LKP_SCRIPT"
    fi
done

# Append all remaining test cases last
for test_case in "${file_array[@]}"
do
    if [[ $test_case == *.yaml && $test_case != h*.yaml && $test_case != e*.yaml ]]; then
        echo "    \"lkp run $lkp_dir/splits/$test_case\"" >> "$LKP_SCRIPT"
    fi
done

echo ")" >> "$LKP_SCRIPT"

# Add all the functions
cat <<'EOF' >> "$LKP_SCRIPT"
convert_elapsed_time() {
    local file=$1
    local elapsed_time=$(grep "Elapsed" "$file" | awk '{print $8}')
    local IFS=':'
    local time_parts=()
    read -r -a time_parts <<< "$elapsed_time"

    local hours=0
    local minutes=0
    local seconds=0

    # Parse time parts based on format (h:m:s or m:s or s)
    if [ ${#time_parts[@]} -eq 3 ]; then
        hours=${time_parts[0]}
        minutes=${time_parts[1]}
        seconds=${time_parts[2]}
    elif [ ${#time_parts[@]} -eq 2 ]; then
        minutes=${time_parts[0]}
        seconds=${time_parts[1]}
    else
        seconds=${time_parts[0]}
    fi

    # Convert everything to seconds using bc for decimal handling
    local total_seconds=$(echo "$hours * 3600 + $minutes * 60 + $seconds" | bc)

    # Round the decimal part if present
    if [[ $total_seconds == *"."* ]]; then
        # Extract decimal part
        local decimal_part=$(echo "$total_seconds" | awk -F. '{print $2}')
        local integer_part=$(echo "$total_seconds" | awk -F. '{print $1}')

        # If decimal >= 5, round up, else round down
        if [ ${decimal_part:0:1} -ge 5 ]; then
            total_seconds=$((integer_part + 1))
        else
            total_seconds=$integer_part
        fi
    fi

    echo "$total_seconds" > /tmp/lkp.result
}

extract_test_info() {
    local full_test_case=$1
    local test_case_string=$(echo "$full_test_case" | sed -E 's/.*\/splits\///')
    local test=$(echo "$test_case_string" | awk -F'-' '{print $1}')
    local type=$(echo "$test_case_string" | sed -E 's/^[^-]+-(.*)\.yaml/\1/')

    find /lkp/result/$test/$type/ -name "*.time" > /tmp/file.name
    cat $(cat /tmp/file.name) > /tmp/lkp.time
    rm -rf /tmp/file.name

    echo "$type" > /tmp/lkp-type
}

cleanup_test_results() {
    local test=$1
    local result_dir="${RESULT_DIR}/${test}"
    
    if [[ -d "$result_dir" ]]; then
        rm -rf "$result_dir"/* || {
            echo "Warning: Failed to clean up $result_dir" >&2
            return 1
        }
    fi
}

run_tests() {
    local test_result_file="${RESULT_DIR}/test.result"

    # Every boot (re)starts the full test suite from the beginning instead
    # of resuming from a previous run, so always clear out old results first.
    rm -f "$test_result_file"

    for current_test in "${test_cases[@]}"; do
        local test_exit=0
        echo "Running: $current_test"

        # Run outside of "set -e" so a failing test is reported clearly
        # instead of silently killing the whole service.
        ${current_test} || test_exit=$?
        if [[ $test_exit -ne 0 ]]; then
            echo "Error: Test execution failed for $current_test (exit code $test_exit)" >&2
            exit 1
        fi

        extract_test_info "$current_test"
        touch /lkp/result/test.result
        convert_elapsed_time "/tmp/lkp.time"
        echo "$(cat /tmp/lkp.result)" >> /lkp/result/test.result

        # Cleanup test directories
        rm -rf /lkp/result/hackbench/*
        rm -rf /lkp/result/ebizzy/*
        rm -rf /lkp/result/unixbench/*
    done
}

# Main execution
run_tests

# Update reboot log
mkdir -p /var/log/lkp-automation-data
{
    echo ''
    echo '2'
} >> /var/log/lkp-automation-data/reboot-log
EOF

# Make the script executable
chmod 777 "$LKP_SCRIPT"

cd /etc/systemd/system/
touch auto_lkp.service
truncate -s 0 auto_lkp.service
echo -e "[Unit]" >> auto_lkp.service
echo -e "Description=LKP Tests Service" >> auto_lkp.service
echo -e "After=network.target" >> auto_lkp.service
echo -e "\n" >> auto_lkp.service
echo -e "[Service]" >> auto_lkp.service
echo -e "WorkingDirectory=/var/lib" >> auto_lkp.service
echo -e "ExecStart=/bin/bash /var/lib/auto_lkp.sh" >> auto_lkp.service
echo -e "\n" >> auto_lkp.service
echo -e "[Install]" >> auto_lkp.service
echo -e "WantedBy=multi-user.target" >> auto_lkp.service

# On SELinux-enforcing distros (CentOS/Rocky/Oracle/RHEL/Anolis/Euler/CloudOS)
# systemd will refuse to run a script placed under /var/lib unless it carries
# the expected file context. restorecon is a no-op (and safe to call) on
# systems without SELinux, so this keeps the service working across every
# supported distro without needing distro-specific branching.
if command -v restorecon &> /dev/null; then
    restorecon -F "$LKP_SCRIPT" /etc/systemd/system/auto_lkp.service &> /dev/null || true
fi
