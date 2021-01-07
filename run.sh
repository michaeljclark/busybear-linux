#!/bin/bash

QEMU_PATH="../qemu-pinning/build/qemu-system-riscv64 "
QEMU_PARAMS="-nographic -kernel build/linux-5.9.6/arch/riscv/boot/Image -machine virt -append \"root=/dev/vda ro console=ttyS0\" -drive file=./busybear.bin,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 -accel tcg,thread=multi -smp 32 -m 8G"
PINNING_PARAMS=" "

if [ -z "$1" ]
then
	echo "./run.sh no_pinning|pinning"
	exit 1
fi

for core in $(seq 0 31);
do
	if [ $core -le 31 ]; then
		PINNING_PARAMS="${PINNING_PARAMS} -vcpu vcpunum=${core},affinity=${core}"
	else
		PINNING_PARAMS="${PINNING_PARAMS} -vcpu vcpunum=${core},affinity=$((${core} % 32))"
	fi
done

#echo ${QEMU_PATH} ${QEMU_PARAMS} ${PINNING_PARAMS}

if [ "$1" = "pinning" ]
then
	eval "exec ${QEMU_PATH} ${QEMU_PARAMS} ${PINNING_PARAMS}"
elif [ "$1" = "no_pinning" ]
then
	eval "exec ${QEMU_PATH} ${QEMU_PARAMS}"
fi
