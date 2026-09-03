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

####################################################################
# EL8-vintage modular-Ruby compatibility fix.
#
# Some EL8-based RHEL-family systems (hit so far on Anolis OS 8.x; likely
# also affects RHEL/CentOS/Rocky/Alma 8.x, since they share the same
# AppStream module data) default to the "ruby:2.5" module stream, which is
# far too old for several gem dependencies this repo needs -- rubocop's
# "prism" needs Ruby>=2.7, tins' "io-console" needs Ruby>=2.6,
# activesupport's "zeitwerk" needs Ruby>=3.2, and bundler itself needs
# Ruby>=3.0. This has nothing to do with which distro it is, only with
# whether dnf module streams are in play and which one is enabled, so it's
# detected purely at runtime:
#   - dnf module list ruby returning no "ruby" stream at all (EL9+ dropped
#     most AppStream modularity, and apt-based distros have no concept of
#     this) makes this a no-op.
#   - An already-modern (>=3.0) system ruby also makes this a no-op.
#   - Only runs if this system's own repos actually advertise a >=3.0
#     stream to switch to.
# Must run before the package install loop below, since that loop installs
# "ruby" (and friends) from whichever module stream is enabled at the time.
ensure_modern_ruby_module() {
	command -v dnf &> /dev/null || return 0

	local newest
	newest=$(dnf module list ruby 2>/dev/null | awk '/^ruby[[:space:]]/{print $2}' | grep -E '^[0-9]+(\.[0-9]+)?$' | sort -t. -k1,1n -k2,2n | tail -1)
	[[ -n "$newest" ]] || return 0
	[[ "${newest%%.*}" -ge 3 ]] || return 0

	if command -v ruby &> /dev/null && ruby -e 'exit(RUBY_VERSION.to_f >= 3.0 ? 0 : 1)' &> /dev/null; then
		return 0
	fi

	echo "System Ruby is too old for lkp-tests' gem dependencies (module stream ruby:2.5 or similar); switching to the newer ruby:$newest stream available in this system's repos..."
	dnf module reset -y ruby &> /dev/null
	dnf module enable -y "ruby:$newest" &> /dev/null
	# Remove whatever was already installed from the old stream so the
	# normal package loop below reinstalls it fresh from the new one.
	dnf remove -y ruby ruby-libs ruby-devel rubygems-devel rubygem-psych &> /dev/null
}
ensure_modern_ruby_module

# Some RHEL-family systems (hit so far on Anolis OS 8.10) don't enable EPEL
# by default, and several packages this repo's dependencies/packages.txt
# expects (fakeroot, capstone-devel, libunwind-devel, ...) live there
# instead of in base/AppStream/PowerTools -- causing otherwise-avoidable
# "No match for argument" failures. epel-release is itself an ordinary
# package published from those same base repos on every RHEL-family
# distro's own mirrors (not a third-party add-on), so installing it is
# always safe; this is a no-op if epel-release isn't found under this
# exact name in this system's currently-enabled repos at all (e.g.
# because it's already installed, or this particular distro doesn't ship
# it this way).
ensure_epel_enabled() {
	[[ "$installer" == "dnf" || "$installer" == "yum" ]] || return 0
	rpm -q epel-release &> /dev/null && return 0
	"$installer" install -y epel-release &> /dev/null
}
ensure_epel_enabled

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
	if ! gem list -i $gem &> /dev/null; then
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
    # Pass the full spec (name plus any "-v VERSION"), not just the bare
    # name, to "gem list -i": some gems (e.g. bundler, json, bigdecimal)
    # ship as Ruby "default gems" bundled with the interpreter itself, so
    # "gem list -i bundler" is true even when the specific pinned version
    # this script wants isn't actually installed, causing it to be
    # silently skipped.
    if ! gem list -i $gem &> /dev/null; then
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
	# openEuler's system Ruby ships bundler as a "default gem" (e.g. 2.4.10)
	# with no version pin needed by lkp-tests (it has no Gemfile.lock yet).
	# Installing an older pinned bundler version (previously "-v 2.3.26")
	# leaves that default gem's version as the highest one on the system;
	# since default gems have no real libexec/ directory on disk,
	# RubyGems' unconstrained `bundle` binstub picks it and crashes with
	# "cannot load such file -- .../libexec/bundle". Installing the latest
	# bundler instead guarantees it outranks the phantom default gem so
	# the binstub resolves to the real, working install.
	sudo gem install bundler
fi
