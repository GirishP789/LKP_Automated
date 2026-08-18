#!/bin/bash

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

#finding the package manager available on the system
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
    elif command -v pacman &> /dev/null; then
        installer="pacman"
    elif command -v zypper &> /dev/null; then
        installer="zypper"
    elif command -v apk &> /dev/null; then
        installer="apk"
    else
        echo "Package Manager couldn't be recognized. Please contact the maintainer for support."
        exit 1
    fi
}
check_package_manager
echo "Detected Package Manager: $installer"
echo "--------------------------------------------"

# Canonical dependency names below follow RPM (dnf/yum/zypper) conventions, since
# that naming is shared by the majority of the officially supported distros
# (CentOS, Euler, Anolis, CloudOS, Rocky Linux, Oracle, Redhat). The
# *_PKG_MAP arrays below translate a canonical name into the correct package
# name for distros that use a different package manager/naming convention
# (Ubuntu/Velinux via apt, Arch Linux via pacman). zypper/apk are not among
# the officially supported distros but are mapped on a best-effort basis.
#
# A mapped value of "" means the dependency is already bundled with another
# package on that distro (e.g. Arch's "gcc" already includes the C++
# front-end), so it is safely skipped instead of failing.
pkgs_list=(git wget make gcc time tar bc pkg-config libtool ca-certificates rsync cpio \
    rubygems-devel ruby-devel rubygem-psych ruby gcc-c++ cmake automake autoconf bsdtar \
    glibc-static turbojpeg-devel slang-devel libunwind-devel libcap-devel libbabeltrace \
    libbabeltrace-devel numactl-devel flex python3-devel java-17-openjdk fakeroot \
    openssl-devel openssl libcurl-devel patch bison elfutils-libelf-devel elfutils-devel \
    libX11-devel systemtap-sdt-devel perl-ExtUtils-Embed perl-core perl-FindBin \
    mesa-libGL-devel libXext-devel capstone-devel clang clang-devel libpfm libpfm-devel \
    perl-IPC-Run libxslt-devel llvm-devel)

declare -A APT_PKG_MAP=(
    [rubygems-devel]=""
    [ruby-devel]="ruby-dev"
    [rubygem-psych]=""
    [gcc-c++]="g++"
    [bsdtar]="libarchive-tools"
    [glibc-static]=""
    [turbojpeg-devel]="libturbojpeg0-dev"
    [slang-devel]="libslang2-dev"
    [libunwind-devel]="libunwind-dev"
    [libcap-devel]="libcap-dev"
    [libbabeltrace]="libbabeltrace1"
    [libbabeltrace-devel]="libbabeltrace-dev"
    [numactl-devel]="libnuma-dev"
    [python3-devel]="python3-dev"
    [java-17-openjdk]="openjdk-17-jdk"
    [openssl-devel]="libssl-dev"
    [libcurl-devel]="libcurl4-openssl-dev"
    [elfutils-libelf-devel]="libelf-dev"
    [elfutils-devel]="libdw-dev"
    [libX11-devel]="libx11-dev"
    [systemtap-sdt-devel]="systemtap-sdt-dev"
    [perl-ExtUtils-Embed]="libperl-dev"
    [perl-core]="perl"
    [perl-FindBin]="perl"
    [mesa-libGL-devel]="libgl1-mesa-dev"
    [libXext-devel]="libxext-dev"
    [capstone-devel]="libcapstone-dev"
    [clang-devel]="libclang-dev"
    [libpfm]="libpfm4"
    [libpfm-devel]="libpfm4-dev"
    [perl-IPC-Run]="libipc-run-perl"
    [libxslt-devel]="libxslt1-dev"
    [llvm-devel]="llvm-dev"
)

declare -A PACMAN_PKG_MAP=(
    [rubygems-devel]="ruby"
    [ruby-devel]="ruby"
    [rubygem-psych]="ruby"
    [gcc-c++]=""
    [bsdtar]=""
    [glibc-static]=""
    [turbojpeg-devel]="libjpeg-turbo"
    [slang-devel]="slang"
    [libunwind-devel]="libunwind"
    [libcap-devel]="libcap"
    [libbabeltrace]="babeltrace"
    [libbabeltrace-devel]="babeltrace"
    [numactl-devel]="numactl"
    [python3-devel]="python"
    [java-17-openjdk]="jdk17-openjdk"
    [openssl-devel]="openssl"
    [libcurl-devel]="curl"
    [elfutils-libelf-devel]="libelf"
    [elfutils-devel]="elfutils"
    [libX11-devel]="libx11"
    [systemtap-sdt-devel]="systemtap"
    [perl-ExtUtils-Embed]="perl"
    [perl-core]="perl"
    [perl-FindBin]="perl"
    [mesa-libGL-devel]="mesa"
    [libXext-devel]="libxext"
    [capstone-devel]="capstone"
    [clang-devel]=""
    [libpfm]="libpfm"
    [libpfm-devel]="libpfm"
    [perl-IPC-Run]="perl-ipc-run"
    [libxslt-devel]="libxslt"
    [llvm-devel]="llvm"
)

# openSUSE (zypper) mostly follows RPM naming already used as the canonical
# name, only override the handful of packages known to differ.
declare -A ZYPPER_PKG_MAP=(
    [glibc-static]="glibc-devel-static"
    [turbojpeg-devel]="libjpeg8-devel"
    [libbabeltrace]="babeltrace"
    [libbabeltrace-devel]="babeltrace-devel"
    [capstone-devel]="capstone-devel"
    [perl-IPC-Run]="perl-IPC-Run"
)

# Alpine (apk) is not officially supported; best-effort mapping using its
# "-dev" suffix convention (closer to Debian than RPM).
declare -A APK_PKG_MAP=(
    [rubygems-devel]=""
    [ruby-devel]="ruby-dev"
    [rubygem-psych]=""
    [gcc-c++]="g++"
    [bsdtar]=""
    [glibc-static]=""
    [turbojpeg-devel]="libjpeg-turbo-dev"
    [slang-devel]="slang-dev"
    [libunwind-devel]="libunwind-dev"
    [libcap-devel]="libcap-dev"
    [libbabeltrace]="babeltrace"
    [libbabeltrace-devel]="babeltrace-dev"
    [numactl-devel]="numactl-dev"
    [python3-devel]="python3-dev"
    [java-17-openjdk]="openjdk17"
    [openssl-devel]="openssl-dev"
    [libcurl-devel]="curl-dev"
    [elfutils-libelf-devel]="elfutils-dev"
    [elfutils-devel]="elfutils-dev"
    [libX11-devel]="libx11-dev"
    [systemtap-sdt-devel]=""
    [perl-ExtUtils-Embed]="perl-dev"
    [perl-core]="perl"
    [perl-FindBin]="perl"
    [mesa-libGL-devel]="mesa-dev"
    [libXext-devel]="libxext-dev"
    [capstone-devel]="capstone-dev"
    [clang-devel]="clang-dev"
    [libpfm]="libpfm4"
    [libpfm-devel]="libpfm4-dev"
    [perl-IPC-Run]=""
    [libxslt-devel]="libxslt-dev"
    [llvm-devel]="llvm-dev"
)

gems_list=(text-table "activesupport -v 6.0.0" bigdecimal json racc parser tins term-ansicolor rubocop-ast rubocop flex "bundler -v 2.5.19" git)

failed_pkgs=()
failed_gems=()

# Resolve a canonical dependency name into the correct package name(s) for
# the current package manager. Prints nothing (skip) when the dependency is
# already covered by another package on this distro.
resolve_pkg_name() {
    local canonical="$1"
    local resolved
    case "$installer" in
        apt|apt-get)
            resolved="${APT_PKG_MAP[$canonical]-$canonical}"
            ;;
        pacman)
            resolved="${PACMAN_PKG_MAP[$canonical]-$canonical}"
            ;;
        zypper)
            resolved="${ZYPPER_PKG_MAP[$canonical]-$canonical}"
            ;;
        apk)
            resolved="${APK_PKG_MAP[$canonical]-$canonical}"
            ;;
        *)
            resolved="$canonical"
            ;;
    esac
    echo "$resolved"
}

is_installed() {
    local pkg="$1"
    case "$installer" in
        apt|apt-get)
            dpkg -s "$pkg" &> /dev/null
            ;;
        dnf|yum)
            rpm -q "$pkg" &> /dev/null
            ;;
        pacman)
            pacman -Qi "$pkg" &> /dev/null
            ;;
        zypper)
            rpm -q "$pkg" &> /dev/null
            ;;
        apk)
            apk info -e "$pkg" &> /dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

# perf's package name/availability is special-cased per distro: on Ubuntu it
# is split per-kernel-version (linux-tools-$(uname -r)), everywhere else a
# single "perf" package (or Arch's "linux-tools" group member) provides it.
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
        pacman)
            pacman -S --noconfirm --needed perf &> /dev/null
            ;;
        zypper)
            zypper --non-interactive install perf &> /dev/null
            ;;
        apk)
            apk add perf &> /dev/null
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
        resolved=$(resolve_pkg_name "$pkg")
        if [[ -z "$resolved" ]]; then
            printf "%-30s : %s\n" "$pkg" "Skipped (bundled)"
            continue
        fi
        status="Success"
        for real_pkg in $resolved; do
            if ! is_installed "$real_pkg"; then
                status="Failed"
            fi
        done
        printf "%-30s : %s\n" "$pkg" "$status"
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
    resolved=$(resolve_pkg_name "$pkg")

    if [[ -z "$resolved" ]]; then
        echo "$pkg is already bundled/not applicable on this distro, skipping......"
        continue
    fi

    for real_pkg in $resolved; do
        if is_installed "$real_pkg"; then
            echo "$real_pkg already installed on the system, skipping......"
            continue
        fi

        loading_animation &
        spinner_pid=$!
        echo "Installing $real_pkg, please wait..."
        if [[ $installer == "dnf" ]]; then
            # --allowerasing lets dnf swap "minimal" variants (e.g.
            # curl-minimal/libcurl-minimal on RHEL9+/Fedora) for the full
            # package instead of failing with a file-conflict error.
            dnf install -y --allowerasing "$real_pkg" &> /dev/null
        else
            "$installer" install -y "$real_pkg" &> /dev/null
        fi
        install_status=$?
        kill "$spinner_pid" > /dev/null 2>&1
        if [[ $install_status -ne 0 ]]; then
            failed_pkgs+=("$real_pkg (for $pkg)")
            echo "Failed to install $real_pkg"
        else
            echo "Successfully installed the $real_pkg"
        fi
    done
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
