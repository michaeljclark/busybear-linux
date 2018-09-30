#!/bin/bash

. conf/busybear.config

QEMU_NETDEV="type=tap,script=./scripts/ifup.sh,downscript=./scripts/ifdown.sh"

# locate QEMU
QEMU_SYSTEM_BIN=$(which qemu-system-${ARCH})
if [ -z ${QEMU_SYSTEM_BIN} ]; then
    echo "Cannot locate qemu-system-${ARCH}"
    exit 1
fi

sudo ${QEMU_SYSTEM_BIN} -nographic -machine virt \
	-kernel build/riscv-pk/bbl \
	-append "root=/dev/vda ro console=ttyS0" \
	-drive file=busybear.bin,format=raw,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-netdev ${QEMU_NETDEV},id=net0 \
	-device virtio-net-device,netdev=net0
