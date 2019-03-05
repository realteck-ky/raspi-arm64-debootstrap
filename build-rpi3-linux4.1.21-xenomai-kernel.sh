#!/bin/bash

export WORK_SPACE=$PWD/xenomai-ws
echo "I made a work-space in $WORK_SPACE"
mkdir $WORK_SPACE
cd $WORK_SPACE

sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install make git libncurses5-dev -y

git clone https://github.com/raspberrypi/tools.git --depth 1
git clone http://git.xenomai.org/xenomai-3.git/ -b v3.0.2 --depth 1
#cd $WORK_SPACE/xenomai-3
#git checkout v3.0.2
#cd $WORK_SPACE
git clone https://github.com/raspberrypi/linux.git -b rpi-4.1.y --depth 1
head  -3  $WORK_SPACE/linux/Makefile

wget http://wiki.csie.ncku.edu.tw/_showraw/patch-xenomai-3-on-bcm-2709.patch

cd $WORK_SPACE/xenomai-3
scripts/prepare-kernel.sh --linux=$WORK_SPACE/linux/ --ipipe=$WORK_SPACE/xenomai-3/kernel/cobalt/arch/arm/patches/ipipe-core-4.1.18-arm-4.patch --arch=arm

cd $WORK_SPACE/linux
cat $WORK_SPACE/patch-xenomai-3-on-bcm-2709.patch | patch -p1

export ARCH=arm
export CROSS_COMPILE=$WORK_SPACE/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-
export INSTALL_MOD_PATH=$WORK_SPACE/xenkernel

cd $WORK_SPACE/linux
make bcm2709_defconfig

#export RPI3_RT_CONFIG_FILE=$WORK_SPACE/linux/arch/arm/configs/rpi3rt_defconfig
#echo CONFIG_CPU_FREQ=n > $RPI3_RT_CONFIG_FILE
#echo CONFIG_CPU_IDLE=n >> $RPI3_RT_CONFIG_FILE
#echo CONFIG_CMA=n >> $RPI3_RT_CONFIG_FILE
#echo CONFIG_COMPACTION=n >> $RPI3_RT_CONFIG_FILE
#echo CONFIG_KGDB=n >> $RPI3_RT_CONFIG_FILE
#echo CONFIG_CMDLINE_FROM_BOOTLOADER=n >> $RPI3_RT_CONFIG_FILE
#echo CONFIG_CMDLINE_EXTEND=y >> $RPI3_RT_CONFIG_FILE

export RT_CONFIG_PATCH=$WORK_SPACE/rpi3rt_defconf_diff.patch
cat << EOS > $RT_CONFIG_PATCH 
diff --git a/.config b/.config
--- a/.config  2018-03-17 18:28:35.819999085 +0900
+++ b/.config      2018-03-17 18:29:55.400191559 +0900
@@ -393,26 +393,6 @@ CONFIG_XENO_ARCH_WANT_TIP=y
 CONFIG_XENO_ARCH_FPU=y
 # CONFIG_XENO_ARCH_SYS3264 is not set
 CONFIG_XENO_ARCH_OUTOFLINE_XNLOCK=y
-
-#
-# WARNING! Page migration (CONFIG_MIGRATION) may increase
-#
-
-#
-# latency.
-#
-
-#
-# WARNING! At least one of APM, CPU frequency scaling, ACPI 'processor'
-#
-
-#
-# or CPU idle features is enabled. Any of these options may
-#
-
-#
-# cause troubles with Xenomai. You should disable them.
-#
 CONFIG_XENO_VERSION_MAJOR=3
 CONFIG_XENO_VERSION_MINOR=0
 CONFIG_XENO_REVISION_LEVEL=2
@@ -568,22 +548,17 @@ CONFIG_FLATMEM=y
 CONFIG_FLAT_NODE_MEM_MAP=y
 CONFIG_HAVE_MEMBLOCK=y
 CONFIG_NO_BOOTMEM=y
-CONFIG_MEMORY_ISOLATION=y
 # CONFIG_HAVE_BOOTMEM_INFO_NODE is not set
 CONFIG_PAGEFLAGS_EXTENDED=y
 CONFIG_SPLIT_PTLOCK_CPUS=4
-CONFIG_COMPACTION=y
-CONFIG_MIGRATION=y
+# CONFIG_COMPACTION is not set
 # CONFIG_PHYS_ADDR_T_64BIT is not set
 CONFIG_ZONE_DMA_FLAG=0
 # CONFIG_KSM is not set
 CONFIG_DEFAULT_MMAP_MIN_ADDR=4096
 CONFIG_CLEANCACHE=y
 CONFIG_FRONTSWAP=y
-CONFIG_CMA=y
-# CONFIG_CMA_DEBUG is not set
-# CONFIG_CMA_DEBUGFS is not set
-CONFIG_CMA_AREAS=7
+# CONFIG_CMA is not set
 # CONFIG_ZSWAP is not set
 # CONFIG_ZPOOL is not set
 # CONFIG_ZBUD is not set
@@ -608,8 +583,8 @@ CONFIG_ZBOOT_ROM_TEXT=0x0
 CONFIG_ZBOOT_ROM_BSS=0x0
 # CONFIG_ARM_APPENDED_DTB is not set
 CONFIG_CMDLINE="console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait"
-CONFIG_CMDLINE_FROM_BOOTLOADER=y
-# CONFIG_CMDLINE_EXTEND is not set
+# CONFIG_CMDLINE_FROM_BOOTLOADER is not set
+CONFIG_CMDLINE_EXTEND=y
 # CONFIG_CMDLINE_FORCE is not set
 # CONFIG_XIP_KERNEL is not set
 # CONFIG_CRASH_DUMP is not set
@@ -622,28 +597,7 @@ CONFIG_CMDLINE_FROM_BOOTLOADER=y
 #
 # CPU Frequency scaling
 #
-CONFIG_CPU_FREQ=y
-CONFIG_CPU_FREQ_GOV_COMMON=y
-CONFIG_CPU_FREQ_STAT=m
-CONFIG_CPU_FREQ_STAT_DETAILS=y
-# CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE is not set
-CONFIG_CPU_FREQ_DEFAULT_GOV_POWERSAVE=y
-# CONFIG_CPU_FREQ_DEFAULT_GOV_USERSPACE is not set
-# CONFIG_CPU_FREQ_DEFAULT_GOV_ONDEMAND is not set
-# CONFIG_CPU_FREQ_DEFAULT_GOV_CONSERVATIVE is not set
-CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
-CONFIG_CPU_FREQ_GOV_POWERSAVE=y
-CONFIG_CPU_FREQ_GOV_USERSPACE=y
-CONFIG_CPU_FREQ_GOV_ONDEMAND=y
-CONFIG_CPU_FREQ_GOV_CONSERVATIVE=y
-
-#
-# CPU frequency scaling drivers
-#
-# CONFIG_CPUFREQ_DT is not set
-# CONFIG_ARM_KIRKWOOD_CPUFREQ is not set
-CONFIG_ARM_BCM2835_CPUFREQ=y
-# CONFIG_QORIQ_CPUFREQ is not set
+# CONFIG_CPU_FREQ is not set
 
 #
 # CPU Idle
@@ -1432,17 +1386,6 @@ CONFIG_REGMAP_MMIO=m
 CONFIG_REGMAP_IRQ=y
 CONFIG_DMA_SHARED_BUFFER=y
 # CONFIG_FENCE_TRACE is not set
-CONFIG_DMA_CMA=y
-
-#
-# Default contiguous memory area size:
-#
-CONFIG_CMA_SIZE_MBYTES=5
-CONFIG_CMA_SIZE_SEL_MBYTES=y
-# CONFIG_CMA_SIZE_SEL_PERCENTAGE is not set
-# CONFIG_CMA_SIZE_SEL_MIN is not set
-# CONFIG_CMA_SIZE_SEL_MAX is not set
-CONFIG_CMA_ALIGNMENT=8
 
 #
 # Bus devices
@@ -2261,12 +2204,10 @@ CONFIG_SERIAL_8250_RUNTIME_UARTS=0
 CONFIG_SERIAL_AMBA_PL011=y
 CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
 # CONFIG_SERIAL_EARLYCON_ARM_SEMIHOST is not set
-# CONFIG_SERIAL_KGDB_NMI is not set
 # CONFIG_SERIAL_MAX3100 is not set
 # CONFIG_SERIAL_MAX310X is not set
 CONFIG_SERIAL_CORE=y
 CONFIG_SERIAL_CORE_CONSOLE=y
-CONFIG_CONSOLE_POLL=y
 CONFIG_SERIAL_OF_PLATFORM=y
 # CONFIG_SERIAL_SCCNXP is not set
 # CONFIG_SERIAL_SC16IS7XX is not set
@@ -2291,7 +2232,6 @@ CONFIG_RAW_DRIVER=y
 CONFIG_MAX_RAW_DEVS=256
 # CONFIG_TCG_TPM is not set
 CONFIG_BRCM_CHAR_DRIVERS=y
-CONFIG_BCM_VC_CMA=y
 CONFIG_BCM2708_VCMEM=y
 CONFIG_BCM_VCIO=y
 CONFIG_BCM_VC_SM=y
@@ -2664,7 +2604,6 @@ CONFIG_THERMAL_DEFAULT_GOV_STEP_WISE=y
 CONFIG_THERMAL_GOV_STEP_WISE=y
 # CONFIG_THERMAL_GOV_BANG_BANG is not set
 # CONFIG_THERMAL_GOV_USER_SPACE is not set
-# CONFIG_CPU_THERMAL is not set
 # CONFIG_THERMAL_EMULATION is not set
 CONFIG_THERMAL_BCM2835=y
 
@@ -5052,13 +4991,7 @@ CONFIG_FTRACE_MCOUNT_RECORD=y
 # CONFIG_MEMTEST is not set
 # CONFIG_SAMPLES is not set
 CONFIG_HAVE_ARCH_KGDB=y
-CONFIG_KGDB=y
-CONFIG_KGDB_SERIAL_CONSOLE=y
-# CONFIG_KGDB_TESTS is not set
-CONFIG_KGDB_KDB=y
-CONFIG_KDB_DEFAULT_ENABLE=0x1
-CONFIG_KDB_KEYBOARD=y
-CONFIG_KDB_CONTINUE_CATASTROPHIC=0
+# CONFIG_KGDB is not set
 # CONFIG_ARM_PTDUMP is not set
 # CONFIG_STRICT_DEVMEM is not set
 CONFIG_ARM_UNWIND=y
EOS

cd $WORK_SPACE/linux
cat $RT_CONFIG_PATCH | patch -p1

make zImage modules dtbs -j8
make modules_install

cd $WORK_SPACE
mkdir $INSTALL_MOD_PATH/boot
$WORK_SPACE/linux/scripts/mkknlimg $WORK_SPACE/linux/arch/arm/boot/zImage $INSTALL_MOD_PATH/boot/zIimage
cp $WORK_SPACE/linux/arch/arm/boot/dts/*.dtb $INSTALL_MOD_PATH/boot/
mkdir $INSTALL_MOD_PATH/boot/overlays/
cp $WORK_SPACE/linux/arch/arm/boot/dts/overlays/*.dtb* $INSTALL_MOD_PATH/boot/overlays/
tar czf ./kernel-4.1.21-xenomai3.tgz $INSTALL_MOD_PATH/*