#!/bin/bash
#https://qiita.com/abtc/items/862e2999d7c136201a44
#trap 'read -p "$0($LINENO) $BASH_COMMAND"' DEBUG

export WORK_SPACE=$PWD/raspi-deboot
export RASPI_ROOT=$WORK_SPACE/raspi-root
export RASPI_BOOT=$WORK_SPACE/raspi-boot
export IMAGE=$WORK_SPACE/RaspbianDeboot_`date +%Y%m%d`.img
export TEMP=$WORK_SPACE/temp
#ipipe-core-4.1.18-arm64-8.patch 25-May-2017 11:47  383K  
#ipipe-core-4.9.51-arm64-4.patch 26-Mar-2018 09:16  390K  
export IPIPE_VER=ipipe-core-4.9.51-arm64-4.patch

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install make git bc libncurses5-dev g++-aarch64-linux-gnu kpartx -y
sudo apt-get install -y qemu-user-static binfmt-support debootstrap git

mkdir -p $WORK_SPACE
cd $WORK_SPACE
ls $WORK_SPACE | grep -v 'temp' | sudo xargs rm -rf

echo "Do you want only kernel compile? [Y/n]"
read Ans
if [ $Ans = "n" ] ; then

echo "Initialize/reuse [Y/n]"
read Ans

if [ $Ans = "Y" ] ; then
  echo "Initialize"

  rm -rf $WORK_SPACE
  mkdir -p $WORK_SPACE
  mkdir -p $TEMP
  cd $TEMP
  git clone https://github.com/raspberrypi/firmware.git firmware --depth 1
  git clone https://github.com/raspberrypi/linux.git rpi-linux
  git clone https://git.xenomai.org/xenomai-3.git xenomai-3 -b next --depth 1
  #git clone https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable.git linux-4.8.y -b linux-4.8.y
  #git clone https://kernel.googlesource.com/pub/scm/linux/kernel/git/stable/linux-stable.git linux-4.9.y -b linux-4.9.y
  #wget -O raspbian.zip https://downloads.raspberrypi.org/raspbian_lite_latest
elif [ $Ans = "n" ] ; then
  echo "Reuse"
else
  echo "Try again!!"
  exit
fi

mkdir $RASPI_ROOT
cd $RASPI_ROOT
#sudo debootstrap --include=ca-certificates,apt,wget --foreign --arch=arm64 xenial . http://ports.ubuntu.com/ubuntu-ports/
sudo debootstrap --include=sudo,apt,openssh-server,wget --foreign --arch=arm64 xenial . http://ports.ubuntu.com/ubuntu-ports/
sudo cp $(which qemu-aarch64-static) ./usr/bin/
sudo chroot . debootstrap/debootstrap --second-stage --verbose

## prepared chroot setting
sudo mount -t sysfs sysfs sys/ 
sudo mount -t proc  proc  proc/
sudo mount -o bind /dev  dev/
sudo mount -o bind /dev/pts dev/pts

## hostname & host setting
sudo echo 'raspberry' | sudo tee $RASPI_ROOT/etc/hostname
sudo echo '127.0.0.1 raspberry' | sudo tee $RASPI_ROOT/etc/host

cat $RASPI_ROOT/etc/apt/sources.list
sudo cat << EOF | sudo tee -a $RASPI_ROOT/etc/apt/sources.list
deb http://jp.archive.ubuntu.com/ports/ xenial main restricted universe multiverse
deb-src http://jp.archive.ubuntu.com/ubuntu/ xenial main restricted universe multiverse
    
deb http://jp.archive.ubuntu.com/ports/ xenial-security main restricted universe multiverse
deb-src http://jp.archive.ubuntu.com/ubuntu/ xenial-security main restricted universe multiverse
    
deb http://jp.archive.ubuntu.com/ports/ xenial-updates restricted main multiverse universe
deb-src http://jp.archive.ubuntu.com/ubuntu/ xenial-updates restricted main multiverse universe
    
deb http://jp.archive.ubuntu.com/ports/ xenial-backports restricted main multiverse universe
deb-src http://jp.archive.ubuntu.com/ubuntu/ xenial-backports restricted main multiverse universe
EOF

cat << EOF | sudo tee $RASPI_ROOT/etc/fstab
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOF

cat << EOF | sudo tee $RASPI_ROOT/etc/fstab
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
<< EOF
sudo -E chroot . wget http://archive.raspbian.org/raspbian.public.key -O - | sudo chroot . apt-key add -
sudo -E chroot . wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | sudo chroot . apt-key add -
EOF
sudo -E chroot . locale-gen en_US.UTF-8
echo "LANG=en_US.UTF-8" | sudo tee $RASPI_ROOT/etc/default/locale
sudo -E chroot . dpkg-reconfigure -f noninteractive locales
echo "Asia/Tokyo" | sudo tee $RASPI_ROOT/etc/timezone
sudo -E chroot . dpkg-reconfigure -f noninteractive tzdata

sudo -E chroot . apt-get update
sudo -E chroot . apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
sudo -E chroot . add-apt-repository ppa:ubuntu-raspi2/ppa-rpi3 -y
sudo -E chroot . dpkg-divert \
  --divert /lib/firmware/brcm/brcmfmac43430-sdio-2.bin \
  --package linux-firmware-raspi2 \
  --rename --add /lib/firmware/brcm/brcmfmac43430-sdio.bin

## user setting
sudo chroot . useradd -m -s /bin/bash pi
sudo chroot . usermod -a -G sudo,staff,kmem,plugdev,audio pi
sudo chroot . passwd pi
fi
## boot partition file
#########################################################
cd $WORK_SPACE
echo "Copying file... (to take many time!!)"
#rm -rf $WORK_SPACE/firmware
cp -r $TEMP/* $WORK_SPACE

cd $WORK_SPACE
wget -nc https://xenomai.org/downloads/ipipe/v4.x/arm64/$IPIPE_VER

<< COMMENT
cd $WORK_SPACE/linux-4.8.y
# git checkout --oneline | grep "Linux 4.8.16"
# > c65ed08 Linux 4.8.16
git checkout c65ed08

cd $WORK_SPACE/rpi-linux
git checkout -b rpi-4.8.y origin/rpi-4.8.y

cd $WORK_SPACE
diff  -purN  $WORK_SPACE/linux-4.8.y  $WORK_SPACE/rpi-linux  | sudo tee  $WORK_SPACE/rpidiff.patch

cd $WORK_SPACE/linux-4.9.y
# git checkout --oneline | grep "Linux 4.9"
# > 089d772 Linux 4.9.51
# >  2f5e58e Linux 4.9.24
git checkout 2f5e58e
COMMENT

cd $WORK_SPACE/rpi-linux
git checkout -b rpi-4.8.y origin/rpi-4.8.y

cd $WORK_SPACE
cp -r rpi-linux rpi-linux-4.8
cp -r rpi-linux rpi-linux-4.9

cd $WORK_SPACE/rpi-linux-4.9
<< LINUX_VERSION
f82786d Linux 4.9.55
f37eb7b Linux 4.9.54
f0cd77d Linux 4.9.38
525571c Linux 4.9.25
a8c90ef Linux 4.9.25
2f5e58e Linux 4.9.24
LINUX_VERSION
git checkout -b rpi-4.9.y origin/rpi-4.9.y
#git checkout 525571c
#git checkout HEAD^

cd $WORK_SPACE/rpi-linux
<< LINUX_VERSION
f82786d Linux 4.9.55
f37eb7b Linux 4.9.54
f0cd77d Linux 4.9.38
525571c Linux 4.9.25
a8c90ef Linux 4.9.25
2f5e58e Linux 4.9.24
LINUX_VERSION
git checkout -b rpi-4.9.y origin/rpi-4.9.y
git checkout 089d772
#git checkout HEAD^
head -3 Makefile

cd $WORK_SPACE
diff -purN rpi-linux/drivers/usb/dwc2 rpi-linux-4.8/drivers/usb/dwc2  | sudo tee rpidiff.patch
diff -purN rpi-linux/arch/arm64/configs rpi-linux-4.9/arch/arm64/configs  | sudo tee -a rpidiff.patch

export LINUX_WS=$WORK_SPACE/rpi-linux
cd $LINUX_WS
patch -tu  -p1 < $WORK_SPACE/rpidiff.patch

#https://gist.github.com/doevelopper/46f78eb2c635835c04867da4cdd13904
echo CFLAGS="-pipe -mcpu=cortex-a53  -march=armv8-a+crc -mtune=cortex-a53 -mfpu=crypto-neon-fp-armv8 \
        -mfloat-abi=hard -funsafe-math-optimizations"
echo CFLAGS="${CFLAGS} -O3 -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations"
echo LDFLAGS="${LDFLAGS} -O3 -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -funsafe-math-optimizations"

echo "Applying xenomai?? [Y/n]"
read Ans

if [ $Ans = "Y" ] ; then
cd $LINUX_WS
$WORK_SPACE/xenomai-3/scripts/prepare-kernel.sh --linux=$LINUX_WS \
--ipipe=$WORK_SPACE/$IPIPE_VER --arch=$ARCH --verbose
echo "Finish Xenomai3!!"
fi

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
cd $LINUX_WS
KERNEL=kernel8
make mrproper
make bcmrpi3_defconfig
#make menuconfig
make -j9 Image modules dtbs
##make modules_install
#exit

# git clone https://github.com/raspberrypi/firmware.git $WORK_SPACE/firmware --depth 1
# cp -r $TEMP/firmware $WORK_SPACE

mkdir $RASPI_BOOT
sudo mount --bind $RASPI_BOOT $RASPI_ROOT/boot
sudo mkdir $RASPI_ROOT/lib/modules/

sudo cp -r $WORK_SPACE/firmware/boot/* $RASPI_ROOT/boot/
sudo make INSTALL_MOD_PATH=$RASPI_ROOT modules_install dtbs_install ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
sudo cp arch/arm64/boot/Image $RASPI_ROOT/boot/kernel8.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb $RASPI_ROOT/boot/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* $RASPI_ROOT/boot/overlays/
sudo cp arch/arm64/boot/dts/overlays/README $RASPI_ROOT/boot/overlays/
sudo cat << EOF | sudo tee -a $RASPI_ROOT/boot/config.txt
kernel=kernel8.img
dev_tree=bcm2837-rpi-3-b.dtb
arm_control=0x200
kernel_address=0x80000
dtparam=audio=on
arm_64bit=1
cmdline=cmdline.txt
gpu_mem_256=1
dtoverlay=pi3-disable-wifi
dtoverlay=pi3-disable-bt
force_turbo=1
smsc95xx.turbo_mode=N
EOF
<< COMMENT
kernel=kernel8.img
dev_tree=bcm2710-rpi-3-b.dtb
arm_control=0x200
kernel_address=0x80000
dtparam=audio=on
arm_64bit=1
cmdline=cmdline.txt
gpu_mem_256=1
dtoverlay=pi3-disable-wifi
dtoverlay=pi3-disable-bt
COMMENT
sudo cat << EOF | sudo tee -a $RASPI_ROOT/boot/cmdline.txt
dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
EOF
# dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootdelay=2

## Docker Install
cd $RASPI_ROOT
<< DOCKER
sudo -E chroot . apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
sudo -E chroot . curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo -E chroot . apt-key add -
sudo -E chroot . apt-key fingerprint 0EBFCD88
sudo -E chroot . add-apt-repository \
   "deb [arch=arm64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo -E chroot . apt-get update
sudo -E chroot . apt-get install -y docker-ce
DOCKER

## create img file
sudo -E chroot . apt-get clean
sudo -E chroot . apt-get autoclean
sudo -E chroot . apt-get autoremove -y
#sudo -E chroot . rpi-update
sudo umount -l ./dev/pts
sudo umount -l ./dev
sudo umount -l ./proc
sudo umount -l ./sys
sudo umount -l ./boot
<< COMMENT
sudo umount $PWD/raspi-deboot/raspi-root/dev/pts
sudo umount $PWD/raspi-deboot/raspi-root/dev
sudo umount $PWD/raspi-deboot/raspi-root/proc
sudo umount $PWD/raspi-deboot/raspi-root/sys
sudo umount $PWD/raspi-deboot/raspi-root/boot
COMMENT

## create sd image
#dd if=/dev/zero bs=1M count=1000  > $IMAGE
dd if=/dev/zero bs=1k count=1000000  > $IMAGE
sudo losetup -f $IMAGE
sudo losetup -a
sudo parted -s /dev/loop0 mklabel msdos
sudo parted -s /dev/loop0 unit MB mkpart primary fat32 -- 4MB 128MB
sudo parted -s /dev/loop0 set 1 boot on
sudo parted -s /dev/loop0 unit MB mkpart primary ext4 -- 128MB -1MB
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

exit









#########################################################

cd $WORK_SPACE
echo "Copying file... (to take many time!!)"
rm -rf $WORK_SPACE/firmware
cp -r $TEMP/* $WORK_SPACE
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

<< XENOMAI
echo "Applying xenomai?? [Y/n]"
read Ans

if [ $Ans = "Y" ] ; then
cd $WORK_SPACE/linux
$WORK_SPACE/xenomai-3/scripts/prepare-kernel.sh --linux=$WORK_SPACE/linux/ \
--ipipe=$WORK_SPACE/$IPIPE_VER --arch=$ARCH --verbose
echo "Finish Xenomai3!!"
fi
XENOMAI

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
sudo make INSTALL_MOD_PATH=/mnt modules_install ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
sudo cp arch/arm64/boot/Image /mnt/boot/kernel8.img
sudo cp arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/
sudo cp arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/overlays/
sudo cp arch/arm64/boot/dts/overlays/README /mnt/boot/overlays/
echo 'kernel=kernel8.img' | sudo tee -a /mnt/boot/config.txt
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
