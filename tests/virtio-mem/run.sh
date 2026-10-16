#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
perl -c tools/VirtioMem.pm
perl tests/virtio-mem/adapter.t
perl tests/virtio-mem/native-contract.t
python3 tests/virtio-mem/lifecycle.py
ui_source=$(mktemp "$TMPDIR/pvemanagerlib.XXXXXX")
trap 'rm -f "$ui_source" "$ui_source.orig" "$ui_source.rej"' EXIT
cp tests/virtio-mem/fixtures/pvemanagerlib.js "$ui_source"
patch --batch --forward --fuzz=0 "$ui_source" patches/PVE-Manager-Memory.js.patch
node tests/virtio-mem/webui.cjs "$ui_source"
bash -n scripts/build-deb.sh scripts/test-profile.sh tools/pve-virtio-mem-env.sh
sh -n debian/pve-virtio-mem.postinst debian/pve-virtio-mem.prerm debian/pve-virtio-mem.postrm
