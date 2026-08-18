#!/bin/bash

# Resolve the script's own directory so it can find dependencies/*.txt
# regardless of the caller's current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PACKAGES_FILE="$SCRIPT_DIR/dependencies/packages.txt"
GEMS_FILE="$SCRIPT_DIR/dependencies/gems.txt"

STOP_FILE="/tmp/stop_lkp_script"

check_exit() {
    if [ -f "$STOP_FILE" ]; then
        echo "Stop file detected. Exiting script..."
        exit 0
    fi
}

trap "echo 'Caught SIGINT. Exiting...'; exit 0" SIGINT

#Checking the distro name
distro_type=$(cat /etc/os-release | grep -i pretty | sed 's/PRETTY_NAME=//')
echo "--------------------------------------------"
echo "Detected Distro: $distro_type"
echo "--------------------------------------------"

capture_error() {
	echo "ERROR: $1"
	# skip the first argument printing as its already printed in echo(using shift command)
	shift
	for arg in "$@"; do
		echo "$arg"
	done
	exit 1
}

capture_warn() {
	echo "Warning: $1"
        for arg in "$@"; do
                echo "$arg"
        done
}

loading_animation() {
    local delay=0.1
    local spinstr='|/-\'
    while :; do
	    for ((i=0; i<${#spinstr}; i++)); do
	        printf "\r%s" "${spinstr:$i:1}"
	        sleep $delay
	    done
	done
}

# This script only supports apt-based (Ubuntu/Velinux) and dnf/yum-based
# (CentOS/Euler/Anolis/CloudOS/Rocky/Oracle/Redhat) distros.
installer=""
check_package_manager() {
    if command -v apt &> /dev/null; then
        installer="apt"
    elif command -v apt-get &> /dev/null; then
        installer="apt-get"
    elif command -v dnf &> /dev/null; then
        installer="dnf"
    elif command -v yum &> /dev/null; then
        installer="yum"
    else
        echo "Package Manager couldn't be recognized (only apt/dnf/yum are supported). Please contact the maintainer for support."
        exit 1
    fi
}
check_package_manager
echo "Detected Package Manager: $installer"
echo "--------------------------------------------"

# apt/apt-get share the same package list ("apt" family), dnf/yum share
# theirs ("yum" family). See dependencies/packages.txt for the actual list.
case "$installer" in
    apt|apt-get) pkg_family="apt" ;;
    dnf|yum) pkg_family="yum" ;;
esac

# The list of OS packages lives in dependencies/packages.txt so new
# dependencies can be added/renamed without touching this script. See that
# file's header for the format.
pkgs_list=()

load_packages_file() {
    local file="$1"
    local current_family="" line header

    if [[ ! -f "$file" ]]; then
        capture_error "Dependency file not found: $file" "The dependencies/ directory should ship alongside lkp-deps.sh."
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue

        if [[ "$line" =~ ^\[([A-Za-z0-9_-]+)\]$ ]]; then
            current_family="${BASH_REMATCH[1],,}"
            continue
        fi

        # Only load packages under the family block matching the package
        # manager actually detected on this system; everything else is
        # ignored.
        if [[ "$current_family" == "$pkg_family" ]]; then
            pkgs_list+=("$line")
        fi
    done < "$file"
}

gems_list=()

load_gems_file() {
    local file="$1"
    local line

    if [[ ! -f "$file" ]]; then
        capture_error "Dependency file not found: $file" "The dependencies/ directory should ship alongside lkp-deps.sh."
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        gems_list+=("$line")
    done < "$file"
}

load_packages_file "$PACKAGES_FILE"
load_gems_file "$GEMS_FILE"

failed_pkgs=()
failed_gems=()

is_installed() {
    local pkg="$1"
    case "$installer" in
        apt|apt-get)
            dpkg -s "$pkg" &> /dev/null
            ;;
        dnf|yum)
            rpm -q "$pkg" &> /dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# perf's package name/availability is special-cased per distro: on Ubuntu it
# is split per-kernel-version (linux-tools-$(uname -r)), while dnf/yum
# provide it via a single "perf" package.
install_perf() {
    if command -v perf &> /dev/null; then
        echo "perf already installed on the system, skipping......"
        return
    fi

    loading_animation &
    spinner_pid=$!
    echo "Installing perf, please wait..."
    case "$installer" in
        apt|apt-get)
            "$installer" install -y linux-tools-common linux-tools-generic "linux-tools-$(uname -r)" &> /dev/null
            ;;
        dnf)
            dnf install -y --allowerasing perf &> /dev/null
            ;;
        yum)
            yum install -y perf &> /dev/null
            ;;
    esac
    install_status=$?
    kill "$spinner_pid" > /dev/null 2>&1

    if command -v perf &> /dev/null; then
        echo "Successfully installed perf"
    else
        failed_pkgs+=("perf")
        echo "Failed to install perf (exit code: $install_status). On Ubuntu this usually means there is no linux-tools package published for kernel $(uname -r); a custom/non-standard kernel may need perf built from source."
    fi
}

print_status() {
    echo "-----------------------------------------"
    echo "Package Installation Status"
    echo "-----------------------------------------"
    printf "%-30s : %s\n" "Package" "Status"
    echo "-----------------------------------------"

    printf "%-30s : %s\n" "perf" "$(command -v perf &> /dev/null && echo Success || echo Failed)"
    for pkg in "${pkgs_list[@]}"; do
        printf "%-30s : %s\n" "$pkg" "$(is_installed "$pkg" && echo Success || echo Failed)"
    done

    echo " "
    echo "-----------------------------------------"    
    echo "Gems Installation Status"
    echo "-----------------------------------------"
    for gem in "${gems_list[@]}"; do
	if ! gem list -i $(echo "$gem" | awk '{print $1}') &> /dev/null; then
	    printf "%-30s : %s\n" "$gem" "Failed"
	else
	    printf "%-30s : %s\n" "$gem" "Success"
	fi
    done
    echo " "
}

install_perf

for pkg in "${pkgs_list[@]}"; do
    check_exit

    if is_installed "$pkg"; then
        echo "$pkg already installed on the system, skipping......"
        continue
    fi

    loading_animation &
    spinner_pid=$!
    echo "Installing $pkg, please wait..."
    if [[ $installer == "dnf" ]]; then
        # --allowerasing lets dnf swap "minimal" variants (e.g.
        # curl-minimal/libcurl-minimal on RHEL9+/Fedora) for the full
        # package instead of failing with a file-conflict error.
        dnf install -y --allowerasing "$pkg" &> /dev/null
    else
        "$installer" install -y "$pkg" &> /dev/null
    fi
    install_status=$?
    kill "$spinner_pid" > /dev/null 2>&1
    if [[ $install_status -ne 0 ]]; then
        failed_pkgs+=("$pkg")
        echo "Failed to install $pkg"
    else
        echo "Successfully installed the $pkg"
    fi
done

for gem in "${gems_list[@]}"; do
    check_exit
    if ! gem list -i $(echo "$gem" | awk '{print $1}') &> /dev/null; then
        loading_animation &
        spinner_pid=$!
        echo "Installing $gem, please wait..."
        gem install $gem &> /dev/null
        install_status=$?
        kill "$spinner_pid" > /dev/null 2>&1
        if [[ $install_status -ne 0 ]]; then
            failed_gems+=("$gem")
            echo "Failed to install $gem"
        else
            echo "Successfully installed $gem"
        fi
    else
        echo "Gem $gem already installed, skipping..."
    fi
done

print_status

if [ ${#failed_pkgs[@]} -eq 0 ]; then
	echo "All required packages are present in the system"
	echo " "

else
	echo " "
	capture_warn "Failed to find packages required for lkp installation" "Packages failed to install: ${failed_pkgs[@]}"
fi


if grep -q -i "euler" /etc/os-release; then
		sudo $installer remove -y rubygem-bundler
        sudo gem install bundler -v 2.3.26
fi
