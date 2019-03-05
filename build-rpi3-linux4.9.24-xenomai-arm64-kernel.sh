#!/bin/bash

#https://qiita.com/takeoverjp/items/5bc9e34e7016bc5b5692
#trap 'read -p "$0($LINENO) $BASH_COMMAND"' DEBUG

export WORK_SPACE=$PWD/xenomai-rpi3-arm64-ws
export TEMP=$WORK_SPACE/temp
export CROSS_COMPILE=aarch64-linux-gnu-
#ipipe-core-4.1.18-arm64-8.patch 25-May-2017 11:47  383K  
#ipipe-core-4.9.51-arm64-4.patch 26-Mar-2018 09:16  390K  
export IPIPE_VER=ipipe-core-4.9.24-arm64-2.patch
export ARCH=arm64
export IMAGE=$WORK_SPACE/RaspbianAarch64Xen_`date +%Y%m%d`.img

echo "Create work space in $WORK_SPACE"
mkdir -p $WORK_SPACE
mkdir -p $TEMP
cd $WORK_SPACE
ls $WORK_SPACE | grep -v 'temp' | xargs rm -rf

echo "Initialize/reuse [Y/n]"
read Ans

if [ $Ans = "Y" ] ; then
  echo "Initialize"
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install make git bc libncurses5-dev g++-aarch64-linux-gnu kpartx -y

  rm -rf $WORK_SPACE
  mkdir -p $WORK_SPACE
  mkdir -p $TEMP
  cd $TEMP
  git clone https://github.com/raspberrypi/firmware.git --depth 1
  git clone https://github.com/raspberrypi/linux.git
  git clone https://git.xenomai.org/xenomai-3.git -b next --depth 1
  wget -O raspbian.zip https://downloads.raspberrypi.org/raspbian_lite_latest
elif [ $Ans = "n" ] ; then
  echo "Reuse"
else
  echo "Try again!!"
  exit
fi

cd $WORK_SPACE
echo "Copying file... (to take many time!!)"
cp -r $TEMP/* $WORK_SPACE
unzip raspbian.zip
cp -r *raspbian-stretch-lite.img $IMAGE
wget -nc https://xenomai.org/downloads/ipipe/v4.x/arm64/older/$IPIPE_VER

cd $WORK_SPACE/linux
<< LINUX_VERSION
f82786d Linux 4.9.55
f37eb7b Linux 4.9.54
f0cd77d Linux 4.9.38
525571c Linux 4.9.25
a8c90ef Linux 4.9.25
2f5e58e Linux 4.9.24
LINUX_VERSION
git checkout rpi-4.9.y-stable
git checkout 525571c
git checkout HEAD^
head -3 Makefile

#https://gist.github.com/doevelopper/46f78eb2c635835c04867da4cdd13904
CFLAGS="-pipe -mcpu=cortex-a53  -march=armv8-a+crc -mtune=cortex-a53 -mfpu=crypto-neon-fp-armv8 \
        -mfloat-abi=hard -funsafe-math-optimizations"
CFLAGS="${CFLAGS} -O3 -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations"
LDFLAGS="${LDFLAGS} -O3 -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations"

echo "Applying xenomai?? [Y/n]"
read Ans

if [ $Ans = "Y" ] ; then
cd $WORK_SPACE/linux
$WORK_SPACE/xenomai-3/scripts/prepare-kernel.sh --linux=$WORK_SPACE/linux/ \
--ipipe=$WORK_SPACE/$IPIPE_VER --arch=$ARCH --verbose
echo "Finish Xenomai3!!"
fi

cd $WORK_SPACE/linux
KERNEL=kernel8
make bcmrpi3_defconfig
#make menuconfig
#make O=${X64_BLRT_BUILD_DIR} source
#make O=${X64_BLRT_BUILD_DIR} openssh-configure
#make O=${X64_BLRT_BUILD_DIR} linux-menuconfig
make -j5 Image modules dtbs
##make modules_install
#exit

#export IMAGE=$WORK_SPACE/RaspbianAarch64Xen_`date +%Y%m%d`.img
#cd $WORK_SPACE/linux
sudo losetup -f
sudo losetup /dev/loop0 $IMAGE
sudo losetup -a
sudo kpartx -avs /dev/loop0
sudo kpartx -l /dev/loop0
sudo ls /dev/mapper/
sudo fdisk -lu /dev/loop0
sudo mount  /dev/mapper/loop0p2 /mnt
# which is 512 : 70254592 = 512 * 137216
sudo mount  /dev/mapper/loop0p1 /mnt/boot
# offset : 4194304 = 512 * 8192, sizelimit: 66060288 = 512 * 129024
#sudo rm -rf /mnt/boot/*
sudo cp -r $WORK_SPACE/firmware/boot/* /mnt/boot/
sudo cp arch/arm64/boot/Image /mnt/boot/kernel8.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/
sudo cp arch/arm64/boot/dts/overlays/README /mnt/boot/overlays/
echo 'kernel=kernel8.img' | sudo tee -a /mnt/boot/config.txt
make INSTALL_MOD_PATH=/mnt modules_install
cat /mnt/boot/config.txt
sudo umount /mnt/boot
sudo umount /mnt
sudo kpartx -d /dev/loop0
sudo ls /dev/mapper/
sudo losetup -d /dev/loop0
sudo losetup -a

exit

<< AFTER_INSTALLED
git clone https://git.xenomai.org/xenomai-3.git -b next --depth 1
cd xenomai-3
./configure --with-core=cobalt  --enable-smp --disable-tls --enable-fortify --enable-maintainer-mode \
--disable-registry --disable-pshared --disable-lorew-clock --enable-assert --disable-doc-install \
--build=x86_64 --host=aarch64-linux-gnu CFLAGS="-march=armv8-a"
make
make install
AFTER_INSTALLED
