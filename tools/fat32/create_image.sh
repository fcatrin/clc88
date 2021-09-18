#!/bin/bash

# this could be done better, for now, use fixed values
SIZE=300000
START=1MiB
LIMIT=152043520

IMG=compy_boot.img

if [ -f $IMG ]; then
	echo "file $IMG already exists\n"
	exit
fi

DEVICE=$(losetup -l | grep $IMG | cut -d " " -f1)

if [ "x$DEVICE" != "x" ]; then
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


