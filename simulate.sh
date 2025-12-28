#!/bin/bash

sudo mkdir -p /tmp/device_1
sudo mkdir -p /tmp/device_2

dd if=/dev/zero of=/tmp/dev_1.img bs=1M count=50
dd if=/dev/zero of=/tmp/dev_2.img bs=1M count=50

mkfs.ext4 /tmp/dev_1.img
mkfs.ext4 /tmp/dev_2.img

echo "/tmp/device_1 /tmp/dev_1.img" > amsh.config
echo "/tmp/device_2 /tmp/dev_2.img" >> amsh.config

echo "Simulation ready. Your "devices" are the img files"

mkdir -p /tmp/temporary_setup

sudo mount -o loop /tmp/dev_1.img /tmp/temporary_setup
sudo mkdir -p /tmp/temporary_setup/Documente /tmp/temporary_setup/Alte_fisiere
sudo touch /tmp/temporary_setup/Documente/un_fisier
sudo umount /tmp/temporary_setup

sudo mount -o loop /tmp/dev_2.img /tmp/temporary_setup
sudo mkdir -p /tmp/temporary_setup/Muzica /tmp/temporary_setup/Poze /tmp/temporary_setup/Facultate
sudo touch /tmp/temporary_setup/Muzica/cantec1 /tmp/temporary_setup/Muzica/cantec2
sudo touch /tmp/temporary_setup/Poze/poza1 
sudo touch /tmp/temporary_setup/Facultate/ASC /tmp/temporary_setup/Facultate/ITBI
sudo umount /tmp/temporary_setup

rmdir /tmp/temporary_setup