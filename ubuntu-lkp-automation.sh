#!/bin/bash

loc=$(cd ../ && pwd)
sudo apt install make -y

sudo apt update -y

sudo apt install git -y

sudo apt update -y

cd $loc 

git clone https://github.com/intel/lkp-tests/

cd $loc/lkp-tests

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

sudo make install -y

sudo lkp install -y

mkdir $loc/lkp-tests/splits

cd $loc/lkp-tests/splits

lkp split-job $loc/lkp-tests/jobs/hackbench.yaml

lkp split-job $loc/lkp-tests/jobs/ebizzy.yaml

lkp split-job $loc/lkp-tests/jobs/unixbench.yaml

lkp install $loc/lkp-tests/splits/hackbench-pipe-8-process-100%.yaml -y

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



