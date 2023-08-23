#!/bin/bash

set -e

if test "${ARCH}" = "riscv64" -a -f conf/parsec.config ; then
    . conf/parsec.config
fi

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
rm -rf mnt
mkdir mnt

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
            ln -s $(basename $(realpath $lib)) $2/$(basename $lib)
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

    # now we have installed busybox in /tmp
    cp -r /tmp/mnt .

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
    cp build/busybox-${BUSYBOX_VERSION}-${ARCH}/busybox mnt/bin/
    cp build/dropbear-${DROPBEAR_VERSION}-${ARCH}/dropbear mnt/sbin/
    if [ -n "${PARSEC_HOME}" -a -d "${PARSEC_HOME}" ]; then
        mkdir -p mnt/root/bin
        find ${PARSEC_HOME} -type f -executable | xargs file | grep RISC-V | awk -F: '{print $1}' | grep inst | xargs -I pwet cp pwet mnt/root/bin
        for dir in $(find ${PARSEC_HOME} -name input_sim\*.tar | sed -e "s+${PARSEC_HOME}/*++" | xargs dirname)
        do
            mkdir -p mnt/root/${dir}
            cd mnt/root/${dir}
            for size in large medium small
                do
                   tar xf ${PARSEC_HOME}/${dir}/input_sim${size}.tar
                done
            cd - > /dev/null
        done
        tar xf ${PARSEC_HOME}/pkgs/apps/blackscholes/inputs/input_native.tar -C mnt/root/pkgs/apps/blackscholes/inputs
        tar xf ${PARSEC_HOME}/pkgs/apps/bodytrack/inputs/input_native.tar -C mnt/root/pkgs/apps/bodytrack/inputs
        cp ${PARSEC_HOME}/parsec_exec mnt/root
        cp ${PARSEC_HOME}/parsec_eval mnt/root
    fi

    # check that the cross-dev env contains the sysroot directory
    # probably should do that earlier, ...
    SYSROOT=$(realpath ${GCC_DIR}/sysroot/)
    if [ -z "${SYSROOT}" ] ; then
        echo "You must use a linux capable cross-dev environment"
        exit
    fi

    # copy libraries
    if [ -d ${SYSROOT}/usr/lib${ARCH/riscv/}/${ABI}/ ]; then
        ABI_DIR=lib${ARCH/riscv/}/${ABI}
    else
        ABI_DIR=lib
    fi
    LDSO_NAME=ld-linux-${ARCH}-${ABI}.so.1
    LDSO_TARGET=${SYSROOT}/lib/${LDSO_NAME}
    mkdir -p mnt/${ABI_DIR}/
    copy_libs ${SYSROOT}/lib/ mnt/${ABI_DIR}/
    copy_libs ${SYSROOT}/usr/${ABI_DIR}/ mnt/${ABI_DIR}/
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
    cp bin/ldd mnt/bin/ldd
)

#
# finish
#
cat > mnt/devlist << EOF
/dev         d  755  0  0  -  -
/dev/console c  640  0  0  5  1
/dev/ttyS0   c  640  0  0  4  64
/dev/null    c  640  0  0  1  3
EOF
genext2fs --squash -b $((1024 * ${IMAGE_SIZE})) -d mnt ${IMAGE_FILE}
sync
/sbin/e2fsck -y -f ${IMAGE_FILE}

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
# erase temporary files
#
#rm -rf mnt /tmp/mnt
