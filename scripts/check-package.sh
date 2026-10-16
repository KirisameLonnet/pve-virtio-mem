#!/bin/bash
# Read-only integration check: all patched files live in a disposable staging root.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-virtio-mem-env.sh"
pve_virtio_mem_env tests
[[ $# = 2 ]] || { echo 'usage: check-package.sh qemu-server.deb pve-manager.deb' >&2; exit 1; }
STAGE=$(mktemp -d "$PVE_VIRTIO_MEM_TEST_DIR/package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
for file in "$@"; do
    DEB=$(realpath "$file")
    package=$(dpkg-deb -f "$DEB" Package)
    case "$package" in qemu-server|pve-manager) ;; *) echo 'Unexpected package' >&2; exit 1;; esac
    dpkg-deb -x "$DEB" "$STAGE"
    mkdir -p "$STAGE/var/lib/dpkg/info" "$STAGE/control/$package"
    dpkg-deb -e "$DEB" "$STAGE/control/$package"
    cp "$STAGE/control/$package/md5sums" "$STAGE/var/lib/dpkg/info/$package.md5sums"
done
python3 "$ROOT/tools/pve-virtio-mem-patch" apply --root "$STAGE" --patches "$ROOT/patches"
node "$ROOT/tests/virtio-mem/webui.cjs" "$STAGE/usr/share/pve-manager/js/pvemanagerlib.js"
python3 "$ROOT/tools/pve-virtio-mem-patch" apply --root "$STAGE" --patches "$ROOT/patches"
install -m 644 "$ROOT/tools/VirtioMem.pm" "$STAGE/usr/share/perl5/PVE/QemuServer/VirtioMem.pm"
# On a PVE development host, compile the staged package against installed dependencies.
if [ -f /usr/share/perl5/PVE/Cluster.pm ]; then
    perl -I"$STAGE/usr/share/perl5" -MPVE::QemuServer -MPVE::API2::Qemu -e 'print "PVE modules load successfully\n"'
fi
python3 "$ROOT/tools/pve-virtio-mem-patch" revert --root "$STAGE"
(cd "$STAGE" && md5sum --quiet -c var/lib/dpkg/info/qemu-server.md5sums var/lib/dpkg/info/pve-manager.md5sums)
for file in "$@"; do dpkg-deb -f "$file" Package Version; done
