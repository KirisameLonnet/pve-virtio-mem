#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Build isolated research binaries; never replace PVE's QEMU or install a kernel.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/tools/pve-virtio-mem-env.sh"
pve_virtio_mem_env transparent
[[ $(uname -s) = Linux ]] || { echo 'Build inside a Linux development container.' >&2; exit 1; }
case $(uname -m) in
    x86_64|aarch64) ;;
    *) echo 'Use a Linux x86_64 or aarch64 build host.' >&2; exit 1 ;;
esac
for tool in python3 git clang ld.lld llvm-ar make ninja; do
    command -v "$tool" >/dev/null || { echo "Missing build dependency: $tool" >&2; exit 1; }
done
JOBS=${TRANSPARENT_BUILD_JOBS:-1}
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid build job count' >&2; exit 1; }
ulimit -c 0
RUN=$(mktemp -d "$PVE_VIRTIO_MEM_BUILD_DIR/transparent.XXXXXX")
printf 'Experimental build directory: %s\n' "$RUN"
python3 "$ROOT/experimental/transparent/prepare.py" "$RUN"
mkdir "$RUN/qemu-build"
cd "$RUN/qemu-build"
CC=clang "$RUN/qemu/configure" --target-list=x86_64-softmmu --enable-llfree \
    --disable-docs --disable-werror --disable-gtk --disable-sdl --disable-vnc \
    --disable-opengl --disable-slirp --enable-fdt=system --disable-tools
ninja -j "$JOBS" qemu-system-x86_64
make -C "$RUN/linux" O="$RUN/linux-build" ARCH=x86 LLVM=1 \
    KCONFIG_ALLCONFIG="$ROOT/experimental/transparent/kernel.config" allnoconfig
for option in CONFIG_64BIT CONFIG_LLFREE CONFIG_VIRTIO_LLFREE_BALLOON CONFIG_BLK_DEV_INITRD; do
    grep -qx "$option=y" "$RUN/linux-build/.config" || { echo "Missing required $option" >&2; exit 1; }
done
make -C "$RUN/linux" O="$RUN/linux-build" ARCH=x86 LLVM=1 -j "$JOBS" bzImage
clang --target=x86_64-linux-gnu -fuse-ld=lld -O2 -Wall -Wextra -static -nostdlib -ffreestanding -fno-builtin -fno-stack-protector \
    -fno-pie -mno-red-zone -Wl,--build-id=none \
    "$ROOT/experimental/transparent/guest.c" -o "$RUN/guest-init"
python3 "$ROOT/experimental/transparent/initramfs.py" "$RUN/guest-init" "$RUN/initramfs.gz"
printf 'Ready for isolated acceptance: make -C %q transparent-test TRANSPARENT_BUILD_DIR=%q\n' "$ROOT" "$RUN"
