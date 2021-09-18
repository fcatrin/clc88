#!/bin/bash

# this could be done better, for now, use fixed values
SIZE=300000
START=1MiB
LIMIT=152043520
MOUNTDIR=img.mount

IMG=compy_boot.img

if [ -f $IMG ]; then
	echo "file $IMG already exists"
	exit
fi

sudo umount $MOUNTDIR

DEVICE=$(losetup -l | grep $IMG | cut -d " " -f1)

if [ "x$DEVICE" != "x" ]; then
  echo "sudo losetup -d $DEVICE"
  sudo losetup -d $DEVICE
fi

dd if=/dev/zero of=$IMG bs=512 count=$SIZE

parted $IMG << EOF
mktable msdos
mkpart primary fat32 1 100%
align-check optimal 1
quit
EOF

sudo losetup -o $START --sizelimit $LIMIT -f $IMG

DEVICE=$(losetup -l | grep $IMG | cut -d " " -f1)
echo "mounted as $DEVICE"

sudo mkfs -t vfat -n COMPY $DEVICE 

sudo umount $MOUNTDIR 2>/dev/null
sudo mkdir $MOUNTDIR 2>/dev/null

sudo mount $DEVICE $MOUNTDIR -o uid=$UID
cp -aR files/* $MOUNTDIR
sudo umount $MOUNTDIR

sudo losetup -d $DEVICE
rmdir $MOUNTDIR

