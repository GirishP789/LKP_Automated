#!/bin/bash

echo " "
echo "============================================"
echo "Installing all required dependencies for LKP"
echo "============================================"
echo " "

echo "updating the system"
yum update -y &> /dev/null
echo "installing git"
yum install git -y &> /dev/null

loc=$(cd ../ && pwd)
echo "installing gcc" 
echo "installing make"
yum install gcc make -y &> /dev/null
echo "installing perf"
yum install perf  -y &> /dev/null
echo "installing rubygems-devel"
yum install rubygems-devel -y &> /dev/null
echo "installing ruby-devel"
yum install -y ruby-devel &> /dev/null
echo "installing rubygem-psych"
yum install -y rubygem-psych &> /dev/null
echo "installing bsdtar"
yum install -y bsdtar &> /dev/null
echo "installing glibc-static"
yum install -y glibc-static &> /dev/null
echo "installing turbojpeg"
yum install -y turbojpeg &> /dev/null
echo "installing slang-devel"
yum install -y slang-devel.x86_64 &> /dev/null
echo "installing libunwind-devel"
yum install -y libunwind-devel.x86_64 &> /dev/null
echo "installing libcap-devel"
yum install -y libcap-devel.x86_64 &> /dev/null
echo "installing libbabeltrace"
yum install -y libbabeltrace &> /dev/null
echo "installing numactl-devel"
yum install -y numactl-devel.x86_64  &> /dev/null
echo "installing libbabeltrace-devel"
yum install -y libbabeltrace-devel &> /dev/null
echo "installing python3-devel"
yum install -y python3-devel &> /dev/null
echo "installing numactl-devel"
yum install -y numactl-devel.x86_64 &> /dev/null
echo "installing libcap-devel"
yum install -y libcap-devel &> /dev/null
echo "installing libcurl-minimal"
yum install -y libcurl-minimal &> /dev/null
echo "installing Java-8"
yum install -y java-1.8.0-openjdk-devel &> /dev/null
echo "installing fakeroot"
yum install -y fakeroot &> /dev/null
echo "installing openssl-devel"
yum install openssl-devel -y &> /dev/null
echo "installing openssl"
yum install openssl -y &> /dev/null
echo "installing libcurl"
yum install libcurl -y &> /dev/null
echo "installing libcurl-devel"
yum install libcurl-devel -y &> /dev/null

echo "installing text-table"
gem install text-table &> /dev/null
echo "installing activesupport"
gem install activesupport -v 6.0.0 &> /dev/null
echo "installing ruby"
gem install ruby &> /dev/null
echo "installing bigdecimal"
gem install bigdecimal &> /dev/null
echo "installing json"
gem install json &> /dev/null
echo "installing racc"
gem install racc &> /dev/null
echo "installing parser"
gem install parser &> /dev/null
echo "installing tins"
gem install tins &> /dev/null
echo "installing parser"
gem install parser &> /dev/null
echo "installing term-ansicolor"
gem install term-ansicolor &> /dev/null
echo "installing rubocop-ast"
gem install rubocop-ast &> /dev/null
echo "installing rubocop"
gem install rubocop &> /dev/null
echo "installing flex"
yum install -y flex &> /dev/null
echo "installing bison"
yum install -y bison &> /dev/null
echo "installing elfutils-libelf-devel"
yum install -y elfutils-libelf-devel &> /dev/null
echo "installing elfutils-devel"
yum install -y elfutils-devel &> /dev/null
echo "installing systemtap-sdt-devel"
yum install -y systemtap-sdt-devel &> /dev/null
echo "installing perl-ExtUtils-Embed"
yum install -y perl-ExtUtils-Embed &> /dev/null
echo "installing libcapstone-dev"
yum install -y libcapstone-dev &> /dev/null
echo "installing capstone-devel"
yum install -y capstone-devel &> /dev/null
echo "installing libdw-dev"
yum install -y libdw-dev &> /dev/null
echo "installing systemtap-sdt-dev"
yum install -y systemtap-sdt-dev &> /dev/null
echo "installing libperl-dev"
yum install -y libperl-dev &> /dev/null
echo "installing clang"
yum install -y clang &> /dev/null
echo "installing clang-devel"
yum install -y clang-devel &> /dev/null
echo "installing libpfm"
yum install -y libpfm &> /dev/null
echo "installing libpfm-devel"
yum install -y libpfm-devel &> /dev/null

echo " "
echo "============================================"
echo "Cloning into the LKP-Tests Directory"
echo "============================================"
echo " "
echo "Removing any directory named lkp-tests in the current directory"
rm -rf $loc/lkp-tests &> /dev/null

cd $loc

git clone https://github.com/intel/lkp-tests/

echo " "
echo "==========================================================="
echo "Modifying the installation files in the lkp-tests directory"
echo "==========================================================="
echo " "
cd $loc/lkp-tests
echo "Creating a new file with the distro name for installation in installer directory"
cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/OpenCloudOS
cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/anolis
cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/openeuler


> $loc/lkp-tests/distro/installer/OpenCloudOS
> $loc/lkp-tests/distro/installer/anolis
> $loc/lkp-tests/distro/installer/euler

# Confirm that the file contents were deleted
echo "Contents of '$FILE' deleted."


echo "Creating a new file with the distro name for installation in adaptation-pkg directory"


cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/OpenCloudOS
cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/anolis
cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/openeuler


echo "Changing the source repo link for rt-tests to older rt-tests"
filename="$loc/lkp-tests/programs/hackbench/pkg/PKGBUILD"
line_number=10
new_text='source=("https://www.kernel.org/pub/linux/utils/rt-tests/older/rt-tests-${pkgver}.tar.gz")'
sed -i "${line_number}s|.*|${new_text}|" "${filename}"

line_number1=5
new_text1='url="https://www.kernel.org/pub/linux/utils/rt-tests/older"'
sed -i "${line_number1}s|.*|${new_text1}|" "${filename}"

fn="$loc/lkp-tests/programs/rt-tests/pkg/PKGBUILD"
ln=8
n_t='source=("https://www.kernel.org/pub/linux/utils/rt-tests/older/rt-tests-$pkgver.tar.gz")'
sed -i "${ln}s|.*|${n_t}|" "${fn}"

echo " "
echo "============================================"
echo "Installing and splitting the LKP tests"
echo "============================================"
echo " "
echo "building lkp to /usr/local/bin"
make install &> /dev/null
echo "Installing lkp with dependencies"
yes | lkp install &> /dev/null
echo "Splitting the test-cases into directory named spilts"
mkdir $loc/lkp-tests/splits 

cd $loc/lkp-tests/splits
echo " "
echo "Splitting Hackbench"
echo "--------------------"
lkp split-job $loc/lkp-tests/jobs/hackbench.yaml 
echo " "
echo "Splitting Ebizzy"
echo "--------------------"
lkp split-job $loc/lkp-tests/jobs/ebizzy.yaml
echo " "
echo "Splitting Unixbench"
echo "--------------------"
lkp split-job $loc/lkp-tests/jobs/unixbench.yaml
echo " "
echo "Installing test-cases"
echo "/////////  This might take a while  /////////"
lkp install $loc/lkp-tests/splits/hackbench-pipe-8-process-100%.yaml 

echo " "
echo "============================================"
echo "Creating a service file for running LKP"
echo "============================================"
echo " "

cd $loc/lkp-tests/

touch $loc/lkp-tests/lkp.sh

echo "Creating a script file to run all the required test-cases, in this case they are:"
echo "Hackbench"
echo "Ebizzy"
echo "Unixbench"
echo " "
echo "Writing into lkp.sh"
echo "#!/bin/bash" >> lkp.sh

files=$(ls "$loc/lkp-tests/splits/")

file_array=($files)

for test_case in "${file_array[@]}"
do
  echo "lkp run $loc/lkp-tests/splits/$test_case" >> lkp.sh
done

echo "Making the written script executable"
chmod 777 lkp.sh

echo "Creating a service to run lkp"

cd /etc/systemd/system/
touch lkp.service
truncate -s 0 lkp.service

echo -e "[Unit]" >> lkp.service
echo -e "Description=LKP Tests Service" >> lkp.service
echo -e "After=network.target" >> lkp.service
echo -e "\n" >> lkp.service
echo -e "[Service]" >> lkp.service
echo -e "WorkingDirectory=$loc/lkp-tests" >> lkp.service
echo -e "ExecStart=/bin/bash $loc/lkp-tests/lkp.sh" >> lkp.service
echo -e "\n" >> lkp.service 
echo -e "[Install]" >> lkp.service
echo -e "WantedBy=multi-user.target" >> lkp.service
echo "Reloading daemon"
systemctl daemon-reload
echo "Enabling lkp service"
systemctl enable lkp.service
echo "Starting lkp service"
systemctl start lkp.service



