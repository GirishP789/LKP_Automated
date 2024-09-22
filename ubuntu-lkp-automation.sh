#!/bin/bash

sudo apt install make -y

sudo apt update -y

sudo apt install git -y

sudo apt update -y

git clone https://github.com/intel/lkp-tests/

cd lkp-tests

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

sudo make install -y

sudo lkp install -y

mkdir splits

cd splits

lkp split-job ../jobs/hackbench.yaml

lkp split-job ../jobs/ebizzy.yaml

lkp split-job ../jobs/unixbench.yaml

lkp install /home/amd/lkp-tests/splits/hackbench-pipe-8-process-100%.yaml -y

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



