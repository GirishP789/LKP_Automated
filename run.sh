#!/bin/bash
pip install pyfiglet &> /dev/null
python -m pyfiglet "LKP TESTS"
export HISTIGNORE='*sudo -S*'
# Get the distribution name
distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
user=$(echo $USER)
echo " "
# Print the distribution name
#echo "Distribution: $distro"
loc=$(pwd)
echo "Working directory choosen for lkp is: $loc"
echo " "
echo "/////////////=== To stop this current process of creating LKP, use CTRL+C ===//////////////"
echo " "
sleep 2
# Check if the distro is Ubuntu
echo "DISTRO FOUND: $distro"
echo "CURRENT USER: $user"
echo " "
if [ "$distro" == "ubuntu" ]; then
  if [ "$user" == "amd" ]; then
	  echo 'Amd$1234!' | sudo -S $loc/ubuntu-lkp-automation.sh
  else
	  sudo $loc/ubuntu-lkp-automation.sh
  fi
else
  if [ "$user" == "amd" ]; then
	  echo 'Amd$1234!' |  sudo -S $loc/centos-lkp-automation.sh
  else
	  sudo $loc/centos-lkp-automation.sh
  fi
fi


