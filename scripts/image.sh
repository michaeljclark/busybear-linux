#!/bin/bash

set -e

. conf/busybear.config

#
# locate compiler
#
GCC_DIR=$(dirname $(which ${CROSS_COMPILE}gcc))/..
if [ ! -d ${GCC_DIR} ]; then
    echo "Cannot locate ${CROSS_COMPILE}gcc"
    exit 1
fi

#
# create root filesystem
#
rm -f ${IMAGE_FILE}
dd if=/dev/zero of=${IMAGE_FILE} bs=1M count=${IMAGE_SIZE}
chown ${UID}:${GID} ${IMAGE_FILE}
/sbin/mkfs.ext4 -j -F ${IMAGE_FILE}
test -d mnt || mkdir mnt
mount -o loop ${IMAGE_FILE} mnt

set +e

#
# copy libraries, flattening symlink directory structure
#
copy_libs() {
    for lib in $1/*.so*; do
        if [[ ${lib} =~ (^libgomp.*|^libgfortran.*|.*\.py$) ]]; then
            : # continue
        elif [[ -e "$2/$(basename $lib)" ]]; then
            : # continue
        elif [[ -h "$lib" ]]; then
            ln -s $(basename $(readlink $lib)) $2/$(basename $lib)
        else
            cp -a $lib $2/$(basename $lib)
        fi
    done
}

#
# configure root filesystem
#
(
    set -e

    # create directories
    for dir in root bin dev etc lib lib/modules proc sbin sys tmp \
        usr usr/bin usr/sbin var var/run var/log var/tmp \
        etc/dropbear \
        etc/network/if-pre-up.d \
        etc/network/if-up.d \
        etc/network/if-down.d \
        etc/network/if-post-down.d
    do
        mkdir -p mnt/${dir}
    done

    # copy busybox and dropbear
    cp build/busybox-${BUSYBOX_VERSION}/busybox mnt/bin/
    cp build/dropbear-${DROPBEAR_VERSION}/dropbear mnt/sbin/

    # copy libraries
    if [ -d ${GCC_DIR}/sysroot/usr/lib${ARCH/riscv/}/${ABI}/ ]; then
        ABI_DIR=lib${ARCH/riscv/}/${ABI}
    else
        ABI_DIR=lib
    fi
    LDSO_NAME=ld-linux-${ARCH}-${ABI}.so.1
    LDSO_TARGET=$(readlink ${GCC_DIR}/sysroot/lib/${LDSO_NAME})
    mkdir -p mnt/${ABI_DIR}/
    copy_libs $(dirname ${GCC_DIR}/sysroot/lib/${LDSO_TARGET})/ mnt/${ABI_DIR}/
    copy_libs ${GCC_DIR}/sysroot/usr/${ABI_DIR}/ mnt/${ABI_DIR}/
    if [ ! -e mnt/lib/${LDSO_NAME} ]; then
        ln -s /${ABI_DIR}/$(basename ${LDSO_TARGET}) mnt/lib/${LDSO_NAME}
    fi

    # final configuration
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
)

#
# remove if configure failed
#
if [[ $? -ne 0 ]]; then
    echo "*** failed to create ${IMAGE_FILE}"
    rm -f ${IMAGE_FILE}
else
    echo "+++ successfully created ${IMAGE_FILE}"
    ls -l ${IMAGE_FILE}
fi

#
# finish
#
umount mnt
rmdir mnt
