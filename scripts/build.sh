#!/bin/bash

set -e

. conf/busybear.config

#
# test environment
#
if [ "${RISCV}" = "" ]; then
    echo "error: the RISCV environment variable is not set"
    exit 1
fi
if [ ! -x "${RISCV}/bin/${COMPILER_PREFIX}-gcc" ]; then
    echo "error: ${COMPILER_PREFIX}-gcc is not present in \$RISCV/bin"
    exit 1
fi
for prog in sudo curl openssl rsync; do
    if [ ! "$(basename $(which ${prog}))" = "${prog}" ]; then
        echo "error: ${prog} not found"
        exit 1
    fi
done

#
# download, extract and build busybox and dropbear
#
export MAKEFLAGS=-j4
test -d archives || mkdir archives
test -f archives/busybox-${BUSYBOX_VERSION}.tar.bz2 || \
    curl -L -o archives/busybox-${BUSYBOX_VERSION}.tar.bz2 \
	 https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
test -f archives/dropbear-${DROPBEAR_VERSION}.tar.bz2 || \
    curl -L -o archives/dropbear-${DROPBEAR_VERSION}.tar.bz2 \
	 https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2
test -d build || mkdir build
test -d build/busybox-${BUSYBOX_VERSION} || \
    tar -C build -xjf archives/busybox-${BUSYBOX_VERSION}.tar.bz2
test -d build/dropbear-${DROPBEAR_VERSION} || \
    tar -C build -xjf archives/dropbear-${DROPBEAR_VERSION}.tar.bz2
cp conf/busybox.config build/busybox-${BUSYBOX_VERSION}/.config
test -x build/busybox-${BUSYBOX_VERSION}/busybox || (
    cd build/busybox-${BUSYBOX_VERSION}
    make ARCH=riscv CROSS_COMPILE=${COMPILER_PREFIX}- oldconfig
    make ARCH=riscv CROSS_COMPILE=${COMPILER_PREFIX}-
)
test -x build/dropbear-${DROPBEAR_VERSION}/dropbear || (
    cd build/dropbear-${DROPBEAR_VERSION}
    ./configure --host=${COMPILER_PREFIX} --disable-zlib
    make
)
