#!/bin/bash

set -e

. conf/busybear.config

#
# test environment
#
for var in ARCH ABI CROSS_COMPILE BUSYBOX_VERSION \
    DROPBEAR_VERSION LINUX_KERNEL_VERSION; do
    if [ -z "${!var}" ]; then
        echo "${!var} not set" && exit 1
    fi
done

#
# find executables
#
for prog in ${CROSS_COMPILE}gcc sudo nproc curl openssl rsync; do
    if [ -z $(which ${prog}) ]; then
        echo "error: ${prog} not found in PATH" && exit 1
    fi
done

#
# download busybox, dropbear and linux
#
test -d archives || mkdir archives
test -f archives/busybox-${BUSYBOX_VERSION}.tar.bz2 || \
    curl -L -o archives/busybox-${BUSYBOX_VERSION}.tar.bz2 \
        https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
test -f archives/dropbear-${DROPBEAR_VERSION}.tar.bz2 || \
    curl -L -o archives/dropbear-${DROPBEAR_VERSION}.tar.bz2 \
        https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2
test -f archives/linux-${LINUX_KERNEL_VERSION}.tar.xz || \
    curl -L -o archives/linux-${LINUX_KERNEL_VERSION}.tar.xz \
        https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_KERNEL_VERSION}.tar.xz
        #https://git.kernel.org/torvalds/t/linux-${LINUX_KERNEL_VERSION}.tar.gz

#
# extract busybox, dropbear and linux
#
test -d build || mkdir build
test -d build/busybox-${BUSYBOX_VERSION}-${ARCH} || \
    (tar -C build -xjf archives/busybox-${BUSYBOX_VERSION}.tar.bz2 && \
     mv build/busybox-${BUSYBOX_VERSION} build/busybox-${BUSYBOX_VERSION}-${ARCH})
test -d build/dropbear-${DROPBEAR_VERSION}-${ARCH} || \
    (tar -C build -xjf archives/dropbear-${DROPBEAR_VERSION}.tar.bz2 && \
     mv build/dropbear-${DROPBEAR_VERSION} build/dropbear-${DROPBEAR_VERSION}-${ARCH})
test -d build/linux-${LINUX_KERNEL_VERSION}-${ARCH} || \
    (tar -C build -xJf archives/linux-${LINUX_KERNEL_VERSION}.tar.xz && \
     mv build/linux-${LINUX_KERNEL_VERSION} build/linux-${LINUX_KERNEL_VERSION}-${ARCH})

#
# overwrite variables to support generating 64 and 32 bit kernels
#
BUSYBOX_VERSION=${BUSYBOX_VERSION}-${ARCH}
DROPBEAR_VERSION=${DROPBEAR_VERSION}-${ARCH}
LINUX_KERNEL_VERSION=${LINUX_KERNEL_VERSION}-${ARCH}

#
# set default configurations
#
cp conf/busybox.config build/busybox-${BUSYBOX_VERSION}/.config
cp conf/linux-${ARCH}.config build/linux-${LINUX_KERNEL_VERSION}/.config

#
# build busybox, dropbear and linux
#
export MAKEFLAGS=-j$(nproc)
test -x build/busybox-${BUSYBOX_VERSION}/busybox || (
    cd build/busybox-${BUSYBOX_VERSION}
    make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} oldconfig
    # Install in /tmp to make sure it is a fresh install
    rm -rf /tmp/mnt
    make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=/tmp/mnt install
)
test -x build/dropbear-${DROPBEAR_VERSION}/dropbear || (
    cd build/dropbear-${DROPBEAR_VERSION}
    ./configure --host=${CROSS_COMPILE%-} --disable-zlib
    make
)
test -x build/linux-${LINUX_KERNEL_VERSION}/Image || (
    cd build/linux-${LINUX_KERNEL_VERSION}
    # Quick and dirty hack to avoid known compilation issue
    sed -e 's/^YYLTYPE yylloc;/extern &/' -i scripts/dtc/dtc-lexer.l
    # Allow more than 32 CPUs max when configuring the kernel
    echo "$(awk '/config NR_CPUS/,/^$/{sub(/"8"/,"1024"); print $0;next}{print $0}' arch/riscv/Kconfig)" > arch/riscv/Kconfig
    make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} olddefconfig
    make ARCH=riscv CROSS_COMPILE=${CROSS_COMPILE} Image
)

#
# create filesystem image
#
. ./scripts/image.sh

# run with, e.g, from busybear repo:
#../qemu/build-master/qemu-system-riscv64 -nographic -kernel build/linux-5.9.6/arch/riscv/boot/Image -machine virt -append "root=/dev/vda ro console=ttyS0" -drive file=./busybear.bin,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 -accel tcg,thread=multi -smp 128 -m 16G
