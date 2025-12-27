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