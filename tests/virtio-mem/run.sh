#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
perl -c tools/VirtioMem.pm
perl tests/virtio-mem/adapter.t
python3 tests/virtio-mem/lifecycle.py
bash -n scripts/build-deb.sh scripts/test-profile.sh tools/pve-virtio-mem-env.sh
sh -n debian/pve-virtio-mem.postinst debian/pve-virtio-mem.prerm debian/pve-virtio-mem.postrm
