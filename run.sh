#!/bin/bash
###########################################
# Script to run QEMU with/without pinning #
###########################################

QEMU_PATH="../qemu-pinning/build/qemu-system-riscv64 "
QEMU_PARAMS="-nographic -kernel build/linux-5.9.6/arch/riscv/boot/Image -machine virt -append \"root=/dev/vda ro console=ttyS0\" -drive file=./busybear.bin,format=raw,id=hd0 -device virtio-blk-device,drive=hd0 -accel tcg,thread=multi -m 8G"

if [ -z "$1" ] || [ -z "$2" ]
then
	echo "./run.sh no_pinning|pinning <smp number>"
	exit 1
fi

CPUS_DATA=$(lscpu --all --parse=SOCKET,CORE,CPU | grep -vP '^(#)' | sort -t ',' -n)

THREADS=$(echo "$CPUS_DATA" | wc -l)
CORES=$(echo "$CPUS_DATA" | cut -d ',' -f 2 | sort | uniq | wc -l)
SOCKETS=$(echo "$CPUS_DATA" | cut -d ',' -f 1 | sort | uniq | wc -l)

LIST=()
while read cpu_entry; do
  LIST+=($(echo $cpu_entry | cut -d ',' -f 3))
done <<< "$CPUS_DATA"

if [ $2 = 1 ] || [ $2 -gt 32 ]
then
	QEMU_SMP="-smp $2"
else
	QEMU_SMP="-smp $2,cores=$(($2 / 2)),threads=$(($THREADS / $CORES))"
fi

for vcpu in $(seq 0 $(($2 - 1)));
do
	QEMU_AFFINITIES="$QEMU_AFFINITIES -vcpu vcpunum=$vcpu,affinity=${LIST[$((${vcpu} % $THREADS))]}"
done

if [ "$1" = "pinning" ]
then
	echo "${QEMU_PATH} ${QEMU_PARAMS} ${QEMU_SMP} ${QEMU_AFFINITIES}"
	eval "exec ${QEMU_PATH} ${QEMU_PARAMS} ${QEMU_SMP} ${QEMU_AFFINITIES}"
elif [ "$1" = "no_pinning" ]
then
	QEMU_PARAMS="${QEMU_PARAMS} -smp $2"
	echo "${QEMU_PATH} ${QEMU_PARAMS}"
	eval "exec ${QEMU_PATH} ${QEMU_PARAMS}"
fi
