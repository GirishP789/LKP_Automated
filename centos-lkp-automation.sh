#!/bin/bash

yum install git -y 

yum install gcc make -y

yum install perf  -y
yum install rubygems-devel -y
yum install -y ruby-devel 
yum install -y rubygem-psych 
yum install -y bsdtar 
yum install -y glibc-static 
yum install -y turbojpeg 
yum install -y slang-devel.x86_64 
yum install -y libunwind-devel.x86_64 
yum install -y libcap-devel.x86_64 
yum install -y libbabeltrace 
yum install -y numactl-devel.x86_64  
yum install -y libbabeltrace-devel 
yum install -y python3-devel 
yum install -y numactl-devel.x86_64 
yum install -y libcap-devel 
yum install -y libcurl-minimal 
yum install -y java-1.8.0-openjdk-devel
yum install -y fakeroot
yum install openssl-devel -y
yum install openssl -y
yum install libcurl -y
yum install libcurl-devel -y

gem install text-table
gem install activesupport -v 6.0.0
gem install ruby

gem install bigdecimal
gem install json
gem install racc
gem install parser
gem install tins
gem install parser
gem install term-ansicolor
gem install rubocop-ast
gem install rubocop

yum install -y flex
yum install -y bison
yum install -y elfutils-libelf-devel
yum install -y elfutils-devel
yum install -y systemtap-sdt-devel
yum install -y perl-ExtUtils-Embed
yum install -y libcapstone-dev
yum install -y capstone-devel
yum install -y libdw-dev
yum install -y systemtap-sdt-dev
yum install -y libperl-dev
yum install -y clang
yum install -y clang-devel
yum install -y libpfm
yum install -y libpfm-devel
rm -rf lkp-tests

git clone https://github.com/intel/lkp-tests/

cd lkp-tests

cp /home/amd/lkp-tests/distro/installer/centos /home/amd/lkp-tests/distro/installer/OpenCloudOS
cp /home/amd/lkp-tests/distro/installer/centos /home/amd/lkp-tests/distro/installer/anolis
cp /home/amd/lkp-tests/distro/installer/centos /home/amd/lkp-tests/distro/installer/openEuler

> /home/amd/lkp-tests/distro/installer/OpenCloudOS
> /home/amd/lkp-tests/distro/installer/anolis
> /home/amd/lkp-tests/distro/installer/euler

# Confirm that the file contents were deleted
echo "Contents of '$FILE' deleted."





cp /home/amd/lkp-tests/distro/adaptation-pkg/centos /home/amd/lkp-tests/distro/adaptation-pkg/cloudos
cp /home/amd/lkp-tests/distro/adaptation-pkg/centos /home/amd/lkp-tests/distro/adaptation-pkg/cloud
cp /home/amd/lkp-tests/distro/adaptation-pkg/centos /home/amd/lkp-tests/distro/adaptation-pkg/anolis
cp /home/amd/lkp-tests/distro/adaptation-pkg/centos /home/amd/lkp-tests/distro/adaptation-pkg/euler

filename="/home/amd/lkp-tests/programs/hackbench/pkg/PKGBUILD"
line_number=10
new_text='source=("https://www.kernel.org/pub/linux/utils/rt-tests/older/rt-tests-${pkgver}.tar.gz")'
sed -i "${line_number}s|.*|${new_text}|" "${filename}"

line_number1=5
new_text1='url="https://www.kernel.org/pub/linux/utils/rt-tests/older"'
sed -i "${line_number1}s|.*|${new_text1}|" "${filename}"

fn="/home/amd/lkp-tests/programs/rt-tests/pkg/PKGBUILD"
ln=8
n_t='source=("https://www.kernel.org/pub/linux/utils/rt-tests/older/rt-tests-$pkgver.tar.gz")'
sed -i "${ln}s|.*|${n_t}|" "${fn}"

sudo make install

sudo lkp install

mkdir splits

cd splits

lkp split-job ../jobs/hackbench.yaml

lkp split-job ../jobs/ebizzy.yaml

lkp split-job ../jobs/unixbench.yaml

lkp install /home/amd/lkp-tests/splits/hackbench-pipe-8-process-100%.yaml

cd ..

touch lkp.sh


echo "#!/bin/bash" >> lkp.sh

files=$(ls "/home/amd/lkp-tests/splits/")

file_array=($files)

for test_case in "${file_array[@]}"
do
  echo "lkp run /home/amd/lkp-tests/splits/$test_case" >> lkp.sh
done


chmod 777 lkp.sh

cd /etc/systemd/system/
touch lkp.service
truncate -s 0 lkp.service

echo -e "[Unit]" >> lkp.service
echo -e "Description=LKP Tests Service" >> lkp.service
echo -e "After=network.target" >> lkp.service
echo -e "\n" >> lkp.service
echo -e "[Service]" >> lkp.service
echo -e "WorkingDirectory=/home/amd/lkp-tests" >> lkp.service
echo -e "ExecStart=/bin/bash /home/amd/lkp-tests/lkp.sh" >> lkp.service
echo -e "\n" >> lkp.service 
echo -e "[Install]" >> lkp.service
echo -e "WantedBy=multi-user.target" >> lkp.service

systemctl daemon-reload
systemctl enable lkp.service
systemctl start lkp.service



