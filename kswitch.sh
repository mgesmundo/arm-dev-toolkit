#!/bin/bash
# -----------------------------------------------------------------------
# Title         Kernel Switch
# Author        Marcello Gesmundo
# Description   This script manage more than one kernel for
#               Acme Systems Aria G25 board and easy switch
#               from a kernel version to another
# Usage         To use this script, the first FAT32 partition
#               of the uSD must have a directory for every Linux
#               Kernel version. Example:
#               2.6.39/     -> contains all required files for
#                              Linux kernel 2.6.39+
#               3.11.6/     -> contains all required files for
#                              Linux kernel 3.11.6
#               3.10.0rc2/  -> contains all required files for
#                              Linux kernel 3.10.0-rc2
# Repository    https://github.com/mgesmundo/arm-dev-toolkit/
# Blog          http://www.yoovant.com/
#
# Created on    31/10/2013
# Last update   04/11/2013
#
# -----------------------------------------------------------------------
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

BACKTITLE="Kernel Switch for Aria G25 - Yoovant by Marcello Gesmundo"

# check if dialog is installed
if [ ! `which dialog` ]; then
  read -p "Dialog package not found. Do you want to install it? (y/n): " RES
  
  if [ $RES = "y" ]; then
    aptitude install -y dialog
    if [ ! `which dialog` ]; then
      echo "Dialog package not found."
      exit 1
    fi
    dialog --backtitle "$BACKTITLE" \
           --title "Success" --clear \
           --msgbox "Dialog package installed." \
           15 45
  else
    exit 1
  fi
fi

cleanup()
{
  cd ~
  umount $TMP
  rmdir $TMP
  clear
}

# mount first partition of the sd card
TMP="/mnt/kswitch"
FAT="/dev/mmcblk0p1"
mkdir -p $TMP
mount $FAT $TMP
cd $TMP

# read current kernel version (uname -r) removing unwanted chars
VER=`uname -r | sed 's/[^.0-9rc]//g'`

# get all directories containing required files for kernel
KDIRS=`ls -d */ | sed 's/[^.0-9rc]//g'`

# display a list of the available kernel version (default set to current)
for k in $KDIRS
do
  if [ $k = $VER ]; then
    STATUS="on"
  else
    STATUS="off"
  fi
  KLIST="$KLIST $k Kernel $STATUS"
done

tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

# select kernel
dialog --backtitle "$BACKTITLE" \
       --title "Kernel" --clear \
       --radiolist "Use up and down arrow and space bar to select your required kernel" 15 45 10 \
       $KLIST 2> $tempfile

retval=$?
KCHOICE=`cat $tempfile`
DOREBOOT=false

if [ $retval = 0 -a $KCHOICE != $VER ]; then	# ok pressed and new kernel selected
  # safe copy files into selected kernel directory
  OLDFILES=`ls -l | grep "^-" | awk '{print $9}'`
  NEWFILES=`ls $KCHOICE`
  for f in $NEWFILES
  do
    # copy
    cp $KCHOICE/$f __$f
    # verify
    MD5_SOURCE=`md5sum $KCHOICE/$f`
    MD5_DEST=`md5sum __$f`
    if [ ${MD5_SOURCE:0:32} != ${MD5_DEST:0:32} ]; then
      dialog --backtitle "$BACKTITLE" \
             --title "Error" --clear \
             --msgbox "Error during $f copy. Unable to switch kernel." \
             15 45		

      rm __*
      cleanup
      exit 1
    fi
  done

  # remove old files
  for f in $OLDFILES
  do
    rm $f
  done

  # rename new files
  for f in $NEWFILES
  do
    mv __$f $f
  done

  # IMPORTANT!
  # remove old net rules to avoid renaming network interface if the MAC address is changed
  rm /etc/udev/rules.d/70-persistent-net.rules
  
  # setup complete
  dialog --backtitle "$BACKTITLE" \
         --title "Setup complete" --clear \
         --msgbox "On next boot you have kernel $KCHOICE version." \
         15 45

  DOREBOOT=true
else
  # no changes
  dialog --backtitle "$BACKTITLE" \
         --title "Setup complete" --clear \
         --msgbox "No changes applied." \
         15 45
fi

cleanup

if $DOREBOOT; then
  echo "Rebooting..."
  sync
  sync
  reboot
fi
