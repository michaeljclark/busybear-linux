# busybear-linux

busybear-linux is a tiny RISC-V Linux root filesystem image that targets
the `virt` board in riscv-qemu. As the name suggests, busybear-linux is
a riscv-linux root image comprised of busybox and dropbear.

The root image is intended to demonstrate virtio-net and virtio-block in
riscv-qemu and features a dropbear ssh server which allows out-of-the-box
ssh access to a RISC-V virtual machine.

See the [releases](https://github.com/michaeljclark/busybear-linux/releases)
for pre-built kernel and filesystem images.

## Copyright and License

The busybear build system has been written by and is
copyright (C) 2017 by Michael J. Clark <michaeljclark@mac.com>.
Enhancements to the build system have been contributed by and
are copyright (C) 2017 by Karsten Merker <merker@debian.org>.

The busybear build system is provided under the following license
("MIT license"):

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

## Dependencies

- [riscv-gnu-toolchain](https://github.com/riscv/riscv-gnu-toolchain) (RISC-V Linux toolchain)
- [busybox](https://busybox.net/) (downloaded automatically)
- [dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) (downloaded automatically)
- sudo, curl, openssl and rsync

## Features

- `ntpd` for time configuration
- `klog` for kernel logging
- `syslog` for system logging
- `dropbear` for ssh access
- `busybox` with almost everything enabled

## Configuration

- `conf` contains the linux image build configuration
  - `conf/linux.config` contains the linux-kernel configuration
  - `conf/busybox.config` contains the busybox configuration
  - `conf/busybear.config` contains the image build configuration
    - `ROOT_PASSWORD=busybear`
    - `IMAGE_FILE=busybear.bin`
- `etc` contains the linux guest system configuration
  - `etc/network/interfaces` (guest 192.168.100.2, router 192.168.100.1)
  - `etc/resolv.conf` (nameserver 8.8.8.8, nameserver 8.8.4.4)
  - `etc/ntp.conf` (server 0.pool.ntp.org, server 1.pool.ntp.org)
  - `etc/passwd`, `etc/shadow`, `etc/group` and `etc/hosts`

The default config assumes bridged networking with `192.168.100.1`
on the host and `192.168.100.2` in the guest.

## Build

The build process downloads busybox and dropbear, compiles them and prepares
a root filesystem image to the file `busybear.bin`. The build script needs
to be run in Linux, even if preparing a root filesystem image for macOS.

### busybear-linux

```
git clone --recursive https://github.com/michaeljclark/busybear-linux.git
cd busybear-linux
make
```

### QEMU

```
git clone https://github.com/riscv/riscv-qemu.git
cd riscv-qemu
./configure --target-list=riscv64-softmmu,riscv32-softmmu
make
```

### riscv-linux

_Note: busybear-linux builds linux kernel automatically_

```
git clone https://github.com/riscv/riscv-linux.git
cd riscv-linux
git checkout riscv-linux-4.14
cp ../busybear-linux/conf/linux.config .config
make ARCH=riscv olddefconfig
make ARCH=riscv vmlinux
```

### bbl

_Note: busybear-linux builds bbl automatically_

```
git clone https://github.com/riscv/riscv-pk.git
cd riscv-pk
mkdir build
cd build
../configure \
    --enable-logo \
    --host=riscv64-unknown-elf \
    --with-payload=../../riscv-linux/vmlinux
make
```

## Running

busybear requires the riscv-qemu `virt` board with virtio-block
and virtio-net devices.

The following command starts busybear-linux:

```
./scripts/run-qemu.sh
```

which runs executes this command:

```
sudo qemu-system-riscv64 -nographic -machine virt \
  -kernel bbl -append "root=/dev/vda ro console=ttyS0" \
  -drive file=busybear.bin,format=raw,id=hd0 \
  -device virtio-blk-device,drive=hd0 \
  -netdev type=tap,script=scripts/ifup.sh,downscript=scripts/ifdown.sh,id=net0 \
  -device virtio-net-device,netdev=net0
```

After booting the virtual machine you should be able to ssh into it.

```
$ ssh root@192.168.100.2
The authenticity of host '192.168.100.2 (192.168.100.2)' can't be established.
ECDSA key fingerprint is 3f:4b:69:59:01:c8:b2:9c:fb:52:a5:d4:21:c9:3c:1b.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.100.2' (ECDSA) to the list of known hosts.
root@192.168.100.2's password: 
    ____                   ____                     __    _                 
   / __ )__  _________  __/ __ )___  ____ ______   / /   (_)___  __  ___  __
  / __  / / / / ___/ / / / __  / _ \/ __ `/ ___/  / /   / / __ \/ / / / |/_/
 / /_/ / /_/ (__  ) /_/ / /_/ /  __/ /_/ / /     / /___/ / / / / /_/ />  <  
/_____/\__,_/____/\__, /_____/\___/\__,_/_/     /_____/_/_/ /_/\__,_/_/|_|  
                 /____/                                                     
root@ucbvax:~# uname -a
Linux ucbvax 4.14.0-00030-gc2d852cb2f3d #56 Thu Dec 14 10:12:10 NZDT 2017 riscv64 GNU/Linux
root@ucbvax:~# cat /proc/interrupts 
           CPU0       
  1:        107  riscv,plic0,c000000  10  ttyS0
  7:        115  riscv,plic0,c000000   7  virtio1
  8:        135  riscv,plic0,c000000   8  virtio0
root@ucbvax:~# 
```

Note: the disk image is stateful and needs to be shutdown cleanly.

```
root@ucbvax:~# halt
```

## linux bridged networking

### bridge

`/etc/network/interfaces`
```
iface br0 inet static
  bridge_ports eth0
  address 192.168.100.1
  netmask 255.255.255.0
  network 192.168.100.0
  broadcast 192.168.100.255
```

### ifup script

```
#!/bin/sh

brctl addif br0 $1
ifconfig $1 up
```

### ifdown script

```
#!/bin/sh

ifconfig $1 down
brctl delif br0 $1
```

## macOS bridged networking

These steps show how to setup tuntap bridged networking on macOS:

### install tuntap

Note: the tuntap driver installation requires authorization in the
macOS Security and Privacy section of System Preferences.

```
brew tap caskroom/cask
brew install caskroom/cask/tuntap
```

### create bridge

```
sudo ifconfig bridge1 create
sudo ifconfig bridge1 192.168.100.1/24
```

### ifup script

```
#!/bin/sh
ifconfig bridge1 addm $1
```

### ifdown script

```
#!/bin/sh
ifconfig bridge1 deletem $1
```

### pfctl.rules (packet filter rules)

```
nat on en0 from { 192.168.100.0/24 } to any -> (en0)
pass from {lo0, 192.168.100.0/24} to any keep state
```

### NAT forwarding (guest access to the Internet)

```
sudo sysctl -w net.inet.ip.forwarding=1
sudo pfctl -e
sudo pfctl -F all
sudo pfctl -f pfctl.rules 
```
