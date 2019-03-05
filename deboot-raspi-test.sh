#!/bin/bash
#https://qiita.com/abtc/items/862e2999d7c136201a44
#trap 'read -p "$0($LINENO) $BASH_COMMAND"' DEBUG

export WORK_SPACE=$PWD/raspi-deboot
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export RASPI_ROOT=$WORK_SPACE/raspi-root
export RASPI_BOOT=$WORK_SPACE/raspi-boot
export IMAGE=$WORK_SPACE/RaspbianDeboot_`date +%Y%m%d`.img

sudo apt-get install -y qemu-user-static binfmt-support debootstrap git
## install deboot-strap
sudo rm -rf $WORK_SPACE
mkdir $WORK_SPACE $RASPI_ROOT
cd $RASPI_ROOT
sudo debootstrap --include=ca-certificates,apt,wget --foreign --arch=armhf jessie . http://archive.raspbian.org/raspbian
sudo cp $(which qemu-arm-static) ./usr/bin/
sudo chroot . debootstrap/debootstrap --second-stage --verbose

## prepared chroot setting
sudo mount -t sysfs sysfs sys/ 
sudo mount -t proc  proc  proc/
sudo mount -o bind /dev  dev/
sudo mount -o bind /dev/pts dev/pts

## hostname & host setting
sudo echo raspberry | sudo tee $RASPI_ROOT/etc/hostname
sudo echo 127.0.0.1\traspberry | sudo tee $RASPI_ROOT/etc/host

sudo cat << EOF | sudo tee $RASPI_ROOT/etc/apt/sources.list
deb http://ftp.jaist.ac.jp/raspbian jessie main firmware non-free
deb http://mirrordirector.raspbian.org/raspbian jessie main firmware non-free
deb http://archive.raspberrypi.org/debian jessie main
EOF

sudo cat << EOF | sudo tee $RASPI_ROOT/etc/fstab
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

sudo cat << EOF | sudo tee $RASPI_ROOT/etc/fstab
proc           /proc    proc  defaults         0 0
/dev/mmcblk0p1 /boot    vfat  defaults,noatime 0 0
/dev/mmcblk0p2 /        ext4  defaults,noatime 0 0
tmpfs          /tmp     tmpfs defaults         0 0
tmpfs          /var/tmp tmpfs defaults         0 0
EOF

## package install
#export LANGUAGE = 
#export LC_ALL = 
export LANG=en_US.UTF-8
sudo -E chroot . wget http://archive.raspbian.org/raspbian.public.key -O - | sudo chroot . apt-key add -
sudo -E chroot . wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | sudo chroot . apt-key add -

sudo -E chroot . apt-get update
sudo -E chroot . apt-get -y upgrade
sudo -E chroot . apt-get install -y \
sudo \
openssh-server \
usbmount \
patch \
less \
console-common \
console-data \
console-setup \
tzdata \
most \
locales \
keyboard-configuration \
raspi-config rpi-update

## user setting
sudo chroot . useradd -m -s /bin/bash pi
sudo chroot . usermod -a -G sudo,staff,kmem,plugdev,audio pi
sudo chroot . passwd pi

## boot partition file
git clone https://github.com/raspberrypi/firmware.git $WORK_SPACE/firmware --depth 1

mkdir $RASPI_BOOT
sudo mount --bind $RASPI_BOOT $RASPI_ROOT/boot
sudo cp -R $WORK_SPACE/firmware/boot/* $RASPI_ROOT/boot/
sudo mkdir $RASPI_ROOT/lib/modules/
sudo cp -R $WORK_SPACE/firmware/modules/* $RASPI_ROOT/lib/modules/

## create img file
sudo -E chroot . apt-get clean
sudo -E chroot . apt-get autoclean
sudo -E chroot . apt-get autoremove -y
sudo -E chroot . rpi-update
sudo umount -l ./dev/pts
sudo umount -l ./dev
sudo umount -l ./proc
sudo umount -l ./sys
sudo umount -l ./boot
<< COMMENT
sudo umount ~/Documents/kernelcomp-ws/raspi-deboot/raspi-root/dev/pts
sudo umount ~/Documents/kernelcomp-ws/raspi-deboot/raspi-root/dev
sudo umount ~/Documents/kernelcomp-ws/raspi-deboot/raspi-root/proc
sudo umount ~/Documents/kernelcomp-ws/raspi-deboot/raspi-root/sys
sudo umount ~/Documents/kernelcomp-ws/raspi-deboot/raspi-root/boot
COMMENT

## create sd image
dd if=/dev/zero bs=1M count=3839 > $IMAGE
sudo losetup -f $IMAGE
sudo losetup -a
sudo parted -s /dev/loop0 mklabel msdos
sudo parted -s /dev/loop0 unit cyl mkpart primary fat16 -- 0 16
sudo parted -s /dev/loop0 set 1 boot on
sudo parted -s /dev/loop0 unit cyl mkpart primary ext2 -- 16 -2
sudo losetup -d /dev/loop0
sudo losetup -f -P $IMAGE
sudo mkfs.vfat -n System /dev/loop0p1
sudo mkfs.ext4 -L Storage /dev/loop0p2
sudo mount /dev/loop0p1 -o rw /mnt
sudo cp -R $RASPI_BOOT/* /mnt/
sudo umount /mnt
sudo mount /dev/loop0p2 -o rw /mnt
sudo cp -R $RASPI_ROOT/* /mnt/
sudo umount /mnt
sudo losetup -d /dev/loop0
