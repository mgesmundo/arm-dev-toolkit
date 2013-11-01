#!/bin/sh
# -----------------------------------------------------------------------
# Title         Create rootfs
# Author        Marcello Gesmundo
# Description   This script create a minimal wheezy 7.2 roofs for
#               Acme Systems Aria G25 board
# Usage         To use this script simply type ./create_rootfs.sh
# Last update   31/10/2013
# Repository    https://github.com/mgesmundo/arm-dev-toolkit/
# Blog          http://www.yoovant.com/debian-wheezy-rootfs/
#
# License
#
# Copyright (c) 2013 Yoovant by Marcello Gesmundo. All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
#      copyright notice, this list of conditions and the following
#      disclaimer in the documentation and/or other materials provided
#      with the distribution.
#    * Neither the name of Yoovant nor the names of its
#      contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# -----------------------------------------------------------------------

TARGET_DIR="armel-root"
KERNEL_VER="3.11.6"
MAC_ADDR="00:04:25:12:34:56"

# create target dir
echo "-> create working directory..."
mkdir $TARGET_DIR

# go to working folder
cd $TARGET_DIR

# start debootstrap first stage
echo "-> start debootstrap first stage"
debootstrap --foreign --arch armel wheezy .

# copy qemu-arm-static
cp /usr/bin/qemu-arm-static usr/bin

# start debootstrap second stage
echo "-> start debootstrap second stage"
LC_ALL=C LANGUAGE=C LANG=C chroot . /debootstrap/debootstrap --second-stage
LC_ALL=C LANGUAGE=C LANG=C chroot . dpkg --configure -a

# create required directories
echo "-> create required directories..." 
mkdir media/mmc_p1
mkdir media/data
mkdir -p lib/modules/$KERNEL_VER
touch lib/modules/$KERNEL_VER/modules.dep

# configure network
echo "-> configure network..."
echo ariag25 > etc/hostname
echo nameserver 8.8.8.8 >> etc/resolv.conf
echo nameserver 8.8.4.4 >> etc/resolv.conf
echo deb http://ftp.it.debian.org/debian wheezy main > etc/apt/sources.list
echo deb-src http://ftp.it.debian.org/debian wheezy main >> etc/apt/sources.list
echo deb http://security.debian.org/ wheezy/updates main  >> etc/apt/sources.list
echo deb-src http://security.debian.org/ wheezy/updates main >> etc/apt/sources.list
echo allow-hotplug eth0 >> etc/network/interfaces
echo iface eth0 inet dhcp >> etc/network/interfaces
echo hwaddress ether $MAC_ADDR >> etc/network/interfaces

# enable console on boot
echo "-> enable console..."
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> etc/inittab

# install your required packages
echo "-> install all required packages..."
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get update
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get -y upgrade
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get install -y openssh-server
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get install -y dialog locales dpkg-dev
LC_ALL=C LANGUAGE=C LANG=C chroot . dpkg-reconfigure locales
# other packages that you nedd
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get install -y curl python git

# create fstab
echo "-> create fstab"
FSTAB_FILE="etc/fstab"
echo /dev/mmcblk0p1 /media/mmc_p1 vfat noatime 0 1 > $FSTAB_FILE
echo /dev/mmcblk0p2 / ext4 noatime 0 1 >> $FSTAB_FILE
echo /dev/mmcblk0p3 /media/data ext4 noatime 0 1 >> $FSTAB_FILE
echo proc /proc proc defaults 0 0 >> $FSTAB_FILE

# create root password
echo "-> create root password..."
chroot . passwd

# cleanup
echo "-> cleanup..."
LC_ALL=C LANGUAGE=C LANG=C chroot . apt-get clean
rm usr/bin/qemu-arm-static

# leave current directory
cd ..

echo "-> rootfs done!"