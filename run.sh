#!/bin/bash

distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
user=$(echo $USER)
loc=$(pwd)
lkp_dir=""
lkp_cmd=""
installer=""
pip_command=""
STOP_FILE="/tmp/stop_lkp_script"
lkp_install_status="-1"
test_install_status="-1"
installation_type=""

# Function to check if the stop file exists
check_exit() {
    if [ -f "$STOP_FILE" ]; then
        echo "Stop file detected. Exiting script..."
        exit 0
    fi
}

# Signal handling to allow graceful exit on Ctrl+C
trap "echo 'Caught SIGINT. Exiting...'; exit 0" SIGINT

capture_error() {
        echo "ERROR: $1"
	# skip printing of first argument as already printed above(using shift command)
	shift
        for arg in "$@"; do
                echo "$arg"
        done
        exit 1
}

# This script only supports apt-based (Ubuntu/Velinux) and dnf/yum-based
# (CentOS/Euler/Anolis/CloudOS/Rocky/Oracle/Redhat) distros.
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

check_package_existence() {
	pkg=$1
	if ! command -v $pkg; then
		$installer install -y $pkg &> /dev/null
	fi
}

clone_lkp() {
    sudo rm -rf $loc/lkp-tests
    git clone https://github.com/intel/lkp-tests.git &> /dev/null
	cd lkp-tests
	git reset --hard 0bcdf89

	if command -v lkp; then
		echo "LKP Found on the system in location: $(which lkp)"
		linked_file=$(readlink -f $(which lkp))
		if [[ $linked_file == *"/var/lib/lkp-tests/"* ]]; then
			echo "LKP is already cloned in /var/lib/lkp-tests/, copying the lkp-tests data to different place"
			lkp_dir="/var/lib/.lkp-tests"
			rm -rf $lkp_dir
			mkdir -p $lkp_dir
			cp -rf $loc/lkp-tests/* $lkp_dir/
			cd $loc
		elif [[ $linked_file == *"/var/lib/.lkp-tests/"* ]]; then
			echo "LKP is already cloned in /var/lib/.lkp-tests/, copying the lkp-tests data to different place"
			lkp_dir="/var/lib/lkp-tests"
			rm -rf $lkp_dir
			mkdir -p $lkp_dir
			cp -rf $loc/lkp-tests/* $lkp_dir/
			cd $loc
		else
			echo "LKP is installed in a different location, copying the lkp-tests data to /var/lib/lkp-tests/"
			lkp_dir="/var/lib/lkp-tests"
			mkdir -p $lkp_dir
			cp -rf $loc/lkp-tests/* $lkp_dir/
			cd $loc
		fi
	else
		lkp_dir="/var/lib/lkp-tests"
		rm -rf $lkp_dir
		mkdir -p $lkp_dir
		cp -rf $loc/lkp-tests/* $lkp_dir/
	fi
    cd $loc
}

support_addition() {
    # lkp-tests doesn't ship distro/installer, distro/adaptation-pkg, or
    # distro/adaptation entries for these RHEL-family distros, so they need
    # to be generated here. All three are required:
    #  - distro/installer/$distro is the actual "install these packages"
    #    script lkp-exec/install execs.
    #  - distro/adaptation-pkg/$distro maps names for the makepkg/benchmark
    #    build path (get_dependency_packages called with PKG_TYPE=pkg).
    #  - distro/adaptation/$distro/{default,<version>} maps generic
    #    (Debian-style) dependency names to real package names for plain OS
    #    package installs (get_dependency_packages called without a
    #    PKG_TYPE). Without this, names like "build-essential"/"libc6-dev"
    #    are passed straight through to dnf/yum unmapped and fail to
    #    install, aborting "lkp install" with no clear error (its output is
    #    normally discarded by install_lkp()).
	#
	# distro/installer/centos picks "dnf --allowerasing" vs plain "yum"
	# based on $_system_version (from lib/detect-system.sh), and passes
	# "$extra_option" quoted even when unset. lib/detect-system.sh has no
	# case for opencloudos/anolis/openeuler (they ship /etc/<name>-release,
	# not /etc/redhat-release), so _system_version stays "unknown", the
	# version check silently takes the wrong (yum, no extra_option) branch,
	# and the quoted-but-empty extra_option is passed to dnf as a literal
	# empty argument, which makes dnf fail overall even though every real
	# package installed fine. These distros are always modern dnf-based
	# systems, so write a small fixed installer for them below instead of
	# copying CentOS's version-sniffing (and, for them, broken) one.
	for _d in opencloudos anolis openeuler; do
		cat > $lkp_dir/distro/installer/$_d << 'EOSCRIPT'
# epel-release is intentionally not installed here: these distros ship
# their own extra-packages repo (e.g. EPOL) enabled by default, and
# "epel-release" isn't a valid package name on them.
dnf install -y --allowerasing $*
EOSCRIPT
		chmod +x $lkp_dir/distro/installer/$_d
	done

	cp $lkp_dir/distro/adaptation-pkg/centos $lkp_dir/distro/adaptation-pkg/opencloudos
	cp $lkp_dir/distro/adaptation-pkg/centos $lkp_dir/distro/adaptation-pkg/anolis
	cp $lkp_dir/distro/adaptation-pkg/centos $lkp_dir/distro/adaptation-pkg/openeuler

	rm -rf $lkp_dir/distro/adaptation/opencloudos $lkp_dir/distro/adaptation/anolis $lkp_dir/distro/adaptation/openeuler
	cp -r $lkp_dir/distro/adaptation/centos $lkp_dir/distro/adaptation/opencloudos
	cp -r $lkp_dir/distro/adaptation/centos $lkp_dir/distro/adaptation/anolis
	cp -r $lkp_dir/distro/adaptation/centos $lkp_dir/distro/adaptation/openeuler
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

test_lkp() {
	lkp_cmd=$(which lkp)
	cd $lkp_dir
	
	mkdir -p $lkp_dir/splits
	cd $lkp_dir/splits

	if $lkp_cmd split-job $lkp_dir/jobs/hackbench.yaml &> /dev/null; then
		# if split-job is successful, lkp is in working condition
		lkp_install_status="0"
		# if the splits directory is empty, lkp_install_status will be reverted back to -1 for later checks
		if [ -z "$(ls $lkp_dir/splits)" ]; then
			lkp_install_status="-1"
		else
			# cleaning up the splits directory for further use
			rm -rf $lkp_dir/splits/*
		fi
	fi
}
install_lkp() {
	echo "Initiating the lkp installation"
	$loc/lkp-deps.sh
	cd $lkp_dir
	sudo make install
	lkp_cmd=$(which lkp)
	if command -v yum; then
		support_addition
	fi

	if grep -q -i "velinux" /etc/os-release; then
		sed -i 's/linux-libc-dev:i386/# linux-libc-dev:i386/g' $lkp_dir/distro/depends/lkp-dev
		sed -i 's/libc6-dev:i386/# libc6-dev:i386/g' $lkp_dir/distro/depends/lkp-dev
	fi

	# RHEL9-family distros (CentOS/Euler/Anolis/CloudOS/Rocky/Oracle/Redhat 9)
	# dropped i686/multilib packages from their default repos entirely, so
	# glibc-devel.i686/glibc-static.i686 (pulled in via the generic
	# "libc6-dev:i386" dependency in lkp-dev, mapped through
	# distro/adaptation/*/default) can never be installed there. Left as-is
	# this aborts the whole "lkp install" step with no visible error, since
	# its output is normally discarded below.
	if command -v yum &> /dev/null; then
		sed -i 's/libc6-dev:i386/# libc6-dev:i386/g' $lkp_dir/distro/depends/lkp-dev
	fi

	loading_animation &
    spinner_pid=$!
	echo "Installing lkp, please wait..."
	yes | $lkp_cmd install &> /dev/null
	install_status=$?
	kill "$spinner_pid" > /dev/null 2>&1
	if [[ $install_status -ne 0 ]]; then
		capture_error "LKP installation failed, Manual attention needed"
	fi

}

test_test_case() {
	test_case=$1
	echo "Checking the working state of the installed $test_case"
	$loc/install-"$test_case".sh test "$lkp_dir" "$lkp_cmd"
	if [[ $? -eq 0 ]]; then
		test_install_status="0"
	fi
}

install_test_case() {
	test_case=$1
	echo "Initiating the $1 test case install"
	$loc/install-"$test_case".sh install "$lkp_dir" "$lkp_cmd"
}

#/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#--------------------------------------------MAIN-CODE---------------------------------------------
#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

if [[ $EUID -ne 0 ]]; then
	capture_error "Please run this script as a super user(root)"
fi

# Print out the Heading
pip install pyfiglet &> /dev/null || pip3 install pyfiglet &> /dev/null
if command -v python3 &> /dev/null; then
	pip_command="python3"
elif command -v python &> /dev/null; then
	pip_command="python"
else
	echo "LKP AUTOMATION SETUP"
fi

$pip_command -m pyfiglet "LKP AUTOMATION SETUP"

# Ignore the old sudo entries and capture the new password
export HISTIGNORE='*sudo -S*'


# Get the distribution name
echo " "
echo "-------------------------------------------------------------------------------------------"
echo "To stop this automation script use CTRL+C or create a file at location /tmp/stop_lkp_script"
echo "-------------------------------------------------------------------------------------------"
echo " "
echo "DISTRO FOUND: $(cat /etc/os-release | grep -i pretty | sed 's/PRETTY_NAME=//')"
echo "CURRENT USER: $user"
echo "Package Manager Found on the system: $installer"
echo "Current working directory: $loc"
echo "Please select the installation type:"
echo "    1. VM   : Install LKP and run the test cases automatically in the background"
echo "             (Hackbench, Ebizzy, Unixbench). A systemd service is created so the"
echo "             run resumes automatically after every reboot. Supported on all the"
echo "             distros listed in the README (requires systemd)."
echo "    2. Host : Only Install LKP, I will run the test cases manually later"
echo "             (Recommended for Hosts)"

while true; do
    read -p "Enter your choice (1 for VM, 2 for Host): " installation_choice

    if [[ $installation_choice == "1" ]]; then
        installation_type="1"
        if ! command -v systemctl &> /dev/null; then
            capture_error "The VM option requires systemd (systemctl) to create the background service, but it was not found on this system." "Please re-run and choose option 2 (Host) instead, or run this on a systemd-based distro."
        fi
		echo "NOTE: This script will run the lkp test cases automatically after installation."
		echo "NOTE: This script will rerun when you reboot the system."
		echo "To disable this automatic run or stop the current run please use the command : sudo systemctl stop auto_lkp.service"
        break
    elif [[ $installation_choice == "2" ]]; then
        installation_type="2"
        break
    else
        echo "Invalid choice. Please enter either 1 (VM) or 2 (Host)."
    fi
done

check_exit
check_package_existence git
check_package_existence make

check_exit
clone_lkp

# check wheather the required paths are present in sudoers file or not, if not present add them
$loc/edit-sudoers.sh $user

#change ulimit values if the system is a anolis system
if grep -q -i "anolis" /etc/os-release; then
	echo "Anolis OS detected, changing the ulimit values"
	$loc/change-ulimit.sh
fi

check_exit
if command -v lkp; then
	echo "LKP Found on the system in location: $(which lkp)"
	echo "Checking the working of lkp......"
	test_lkp
	if [[ $lkp_install_status -eq -1 ]]; then
		install_lkp
		test_lkp
		if [[ $lkp_install_status -eq -1 ]]; then
			capture_error "LKP installation Failed, manual attention needed"
		else
			lkp_install_status="-1"
		fi
	else
		# if test_lkp is success, it will change the lkp_install_status value to 0, revert back the value to -1 for later checks
		lkp_install_status="-1"
		echo "LKP installed is in working condition, skipping to test-case checks......"
	fi
else
	install_lkp
	test_lkp
	if [[ $lkp_install_status -eq -1 ]]; then
		capture_error "LKP installation Failed, manual attention needed"
	else
		# if test_lkp is success, it will change the lkp_install_status value to 0, revert back the value to -1 for later checks
		lkp_install_status="-1"
		echo "LKP installed is in working condition, moving on to other checks"
	fi
fi

lkp_cmd=$(which lkp)
mkdir -p $lkp_dir/splits
cd $lkp_dir/splits

sed -i 's/- 1600%/# - 1600%/g' $lkp_dir/jobs/hackbench.yaml
sed -i 's/# - 50%/- 50%/g' $lkp_dir/jobs/hackbench.yaml

$lkp_cmd split-job $lkp_dir/jobs/hackbench.yaml &> /dev/null
$lkp_cmd split-job $lkp_dir/jobs/ebizzy.yaml &> /dev/null
$lkp_cmd split-job $lkp_dir/jobs/unixbench.yaml &> /dev/null

check_exit
echo "=============================="
echo "Initiating the hackbench checks"
if command -v hackbench; then
	echo "LKP Found on the system in location: $(which lkp)"
	test_test_case "hackbench"
fi
if [[ $test_install_status -eq "-1" ]]; then
	install_test_case "hackbench"
	test_test_case "hackbench"
	if [[ $test_install_status -eq "-1" ]]; then
		capture_error "Hackbench did not install properly, manual attention needed"
	else
		test_install_status="-1"
		echo "Hackbench is installed and in working condition"
	fi
else
	test_install_status="-1"
	echo "Hackbench is installed and in working condition"
fi

check_exit
echo "============================"
echo "Initiating the ebizzy checks"
if [[ $test_install_status -eq "-1" ]]; then
        install_test_case "ebizzy"
        test_test_case "ebizzy"
        if [[ $test_install_status -eq "-1" ]]; then
                capture_error "Ebizzy did not install properly, manual attention needed"
        else
                test_install_status="-1"
		echo "Ebizzy is installed and in working condition"
        fi
else
        test_install_status="-1"
        echo "Ebizzy is installed and in working condition"
fi

check_exit
echo "==============================="
echo "Initiating the Unixbench checks"
if [[ $test_install_status -eq "-1" ]]; then
        install_test_case "unixbench"
        test_test_case "unixbench"
        if [[ $test_install_status -eq "-1" ]]; then
                capture_error "Unixbench did not install properly, manual attention needed"
        else
                test_install_status="-1"
		echo "Unixbench is installed and in working condition"
        fi
else
        test_install_status="-1"
        echo "Unixbench is installed and in working condition"
fi

rm -rf /lkp/result/hackbench/*
rm -rf /lkp/result/ebizzy/*
rm -rf /lkp/result/unixbench/*

# Proceed to create the service file only if installation type is 1 (VM)
if [[ $installation_type == "1" ]]; then
	echo "================================================================================"
	echo "Creating service file for automatic LKP test runs on system boot"
	if ! command -v systemctl &> /dev/null; then
		capture_error "systemd (systemctl) is required for the VM option's background service but was not found." "Please install systemd, or re-run and choose option 2 (Host) instead."
	fi
	$loc/create-service.sh $loc $lkp_dir
	echo "Service file created at /etc/systemd/system/auto_lkp.service"
	systemctl daemon-reload
	if ! systemctl enable auto_lkp.service; then
		capture_error "Failed to enable auto_lkp.service, manual attention needed" "Check 'systemctl status auto_lkp.service' and 'journalctl -u auto_lkp.service' for details."
	fi
	if ! systemctl start auto_lkp.service; then
		capture_error "Failed to start auto_lkp.service, manual attention needed" "Check 'systemctl status auto_lkp.service' and 'journalctl -u auto_lkp.service' for details. On SELinux-enforcing distros (CentOS/Rocky/Oracle/RHEL/Anolis/Euler/CloudOS), check 'ausearch -m avc -ts recent' for denials."
	fi
	echo "LKP service started. It will run automatically on system boot."
	echo "To check the status of the service, use: sudo systemctl status auto_lkp.service"
	echo "To stop the service, use: sudo systemctl stop auto_lkp.service"
	echo "=================================================================================="
else
	echo "----------------------------------------------------------------------------------"
	echo "Installation completed. You can run LKP test cases manually using the lkp command."
	echo "----------------------------------------------------------------------------------"
fi