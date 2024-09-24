#!/bin/bash

yum install git -y 

loc1=$(cd ../ && pwd)

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
rm -rf $loc/lkp-tests

cd $loc

git clone https://github.com/intel/lkp-tests/

cd $loc/lkp-tests

cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/OpenCloudOS
cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/anolis
cp $loc/lkp-tests/distro/installer/centos $loc/lkp-tests/distro/installer/openEuler

> $loc/lkp-tests/distro/installer/OpenCloudOS
> $loc/lkp-tests/distro/installer/anolis
> $loc/lkp-tests/distro/installer/euler

# Confirm that the file contents were deleted
echo "Contents of '$FILE' deleted."





cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/OpenCloudOS
cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/anolis
cp $loc/lkp-tests/distro/adaptation-pkg/centos $loc/lkp-tests/distro/adaptation-pkg/euler

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

sudo make install

sudo lkp install

mkdir $loc/lkp-tests/splits

cd $loc/lkp-tests/splits

lkp split-job $loc/lkp-tests/jobs/hackbench.yaml

lkp split-job $loc/lkp-tests/jobs/ebizzy.yaml

lkp split-job $loc/lkp-tests/jobs/unixbench.yaml

lkp install $loc/lkp-tests/splits/hackbench-pipe-8-process-100%.yaml

cd $loc/lkp-tests/

touch $loc/lkp-tests/lkp.sh


echo "#!/bin/bash" >> lkp.sh

files=$(ls "$loc/lkp-tests/splits/")

file_array=($files)

for test_case in "${file_array[@]}"
do
  echo "lkp run $loc/lkp-tests/splits/$test_case" >> lkp.sh
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
echo -e "WorkingDirectory=$loc/lkp-tests" >> lkp.service
echo -e "ExecStart=/bin/bash $loc/lkp-tests/lkp.sh" >> lkp.service
echo -e "\n" >> lkp.service 
echo -e "[Install]" >> lkp.service
echo -e "WantedBy=multi-user.target" >> lkp.service

systemctl daemon-reload
systemctl enable lkp.service
systemctl start lkp.service



