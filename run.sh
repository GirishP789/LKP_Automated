#!/bin/bash

# Get the distribution name
distro=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)

# Print the distribution name
echo "Distribution: $distro"
loc=$(pwd)
echo "$loc"
# Check if the distro is Ubuntu
if [ "$distro" == "ubuntu" ]; then
  echo "Found $distro on this system, installing required dependencies"
  sudo $loc/ubuntu-lkp-automation.sh
else
  echo "Found $distro on this system. installing required dependencies"
  sudo $loc/centos-lkp-automation.sh

fi


