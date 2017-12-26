#!/bin/bash

set -e

. conf/busybear.config

#
# create root filesystem
#
rm -f ${IMAGE_FILE}
dd if=/dev/zero of=${IMAGE_FILE} bs=1M count=${IMAGE_SIZE}
/sbin/mkfs.ext4 -j -F ${IMAGE_FILE}
test -d mnt || mkdir mnt
mount -o loop ${IMAGE_FILE} mnt
( cd mnt && mkdir -p root bin dev lib lib/modules proc sbin sys tmp usr usr/bin usr/sbin var/run var/log var/tmp etc/dropbear etc/network/if-pre-up.d etc/network/if-up.d etc/network/if-down.d etc/network/if-post-down.d )
cp build/busybox-${BUSYBOX_VERSION}/busybox mnt/bin/
cp build/dropbear-${DROPBEAR_VERSION}/dropbear mnt/sbin/
rsync -a --exclude ldscripts --exclude '*.la' --exclude '*.a' ${RISCV}/sysroot/lib/ mnt/lib/
rsync -a etc/ mnt/etc/
hash=$(openssl passwd -1 -salt xyzzy ${ROOT_PASSWORD})
sed -i'' "s:\*:${hash}:" mnt/etc/shadow
chmod 600 mnt/etc/shadow
touch mnt/var/log/lastlog
touch mnt/var/log/wtmp
ln -s ../bin/busybox mnt/sbin/init
ln -s busybox mnt/bin/sh
cp bin/ldd mnt/bin/ldd
mknod mnt/dev/console c 5 1
mknod mnt/dev/ttyS0 c 4 64
mknod mnt/dev/null c 1 3
umount mnt
rmdir mnt
