#!/bin/bash

# Get the distribution name
distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)

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
if [ "$distro" == "ubuntu" ]; then
  echo "Found $distro on this system, installing required dependencies"
  echo " "
  sudo $loc/ubuntu-lkp-automation.sh
else
  echo "Found $distro on this system. installing required dependencies"
  echo " "
  sudo $loc/centos-lkp-automation.sh
fi


