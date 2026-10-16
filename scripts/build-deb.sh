#!/bin/bash
# Stage the Debian source/build tree beneath the project root, never in source.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-virtio-mem-env.sh"
pve_virtio_mem_env deb
mkdir -p "$PVE_VIRTIO_MEM_BUILD_DIR/deb"
RUN=$(mktemp -d "$PVE_VIRTIO_MEM_BUILD_DIR/deb/run.XXXXXX")
STAGE="$RUN/pve-virtio-mem"
mkdir -p "$STAGE"
# No historical binaries, caches, Git state or prior Debian staging artifacts.
tar -C "$ROOT" --exclude='./.git' --exclude='./docs/evidence' --exclude='./debian/.debhelper' \
    --exclude='./debian/pve-virtio-mem' --exclude='./debian/files' \
    --exclude='./debian/*.debhelper' --exclude='./debian/*.substvars' \
    --exclude='./debian/debhelper-build-stamp' -cf - . | tar -C "$STAGE" -xf -
cd "$STAGE"
dpkg-buildpackage -us -uc -b
printf 'Debian output directory: %s\n' "$RUN"
