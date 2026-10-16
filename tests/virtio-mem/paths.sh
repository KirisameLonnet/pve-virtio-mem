#!/bin/bash
# Adapted from the inherited project-path test; exercises only this fork.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/tools/pve-virtio-mem-env.sh"
pve_virtio_mem_env tests
for path in "$TMPDIR" "$TMP" "$TEMP" "$XDG_CACHE_HOME" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache" "$PYTHONPYCACHEPREFIX"; do
    [[ "$path" = "$PVE_VIRTIO_MEM_TMP_ROOT/"* && -d "$path" ]]
done
fixture=$(mktemp -d "$TMPDIR/paths.XXXXXX")
trap 'rm -rf "$fixture"' EXIT
if PVE_VIRTIO_MEM_RUN_DIR=/tmp bash "$ROOT/tools/pve-virtio-mem-env.sh" --exec tests true; then
    echo 'unowned run unexpectedly accepted' >&2; exit 1
fi
if PROJECT_TMP_ROOT=/tmp PVE_VIRTIO_MEM_TMP_ROOT=/tmp PVE_VIRTIO_MEM_RUN_DIR= bash "$ROOT/tools/pve-virtio-mem-env.sh" --exec tests true; then
    echo 'unowned root unexpectedly accepted' >&2; exit 1
fi
env -u PROJECT_TMP_BASE -u PVE_VIRTIO_MEM_TMP_ROOT PROJECT_TMP_ROOT="$fixture/runner/pve-virtio-mem" PVE_VIRTIO_MEM_RUN_DIR= \
    bash "$ROOT/tools/pve-virtio-mem-env.sh" --exec tests bash -c '
        [[ "$TMPDIR" = "$PVE_VIRTIO_MEM_TMP_ROOT/runs/tests/"* ]]
        [[ "$XDG_CACHE_HOME" = "$PVE_VIRTIO_MEM_TMP_ROOT/cache/xdg" ]]
        [[ "$PVE_VIRTIO_MEM_BUILD_DIR" = "$PVE_VIRTIO_MEM_TMP_ROOT/build" ]]
    '
source "$ROOT/tools/lib/project-tmp.sh"
unset PROJECT_TMP_ROOT PROJECT_TMP_BASE
mkdir -p "$fixture/runner" "$fixture/original" "$fixture/workspace"
RUNNER_TEMP="$fixture/runner" PROJECT_ORIGINAL_TMPDIR="$fixture/original"
CI=true
[[ $(project_tmp_resolve pve-virtio-mem "$fixture/workspace") = "$fixture/runner/pve-virtio-mem" ]]
unset RUNNER_TEMP
[[ $(project_tmp_resolve pve-virtio-mem "$fixture/workspace") = "$fixture/original/pve-virtio-mem" ]]
CI=false GITHUB_ACTIONS=false GITLAB_CI=false TF_BUILD=false CIRCLECI=false
[[ $(project_tmp_resolve pve-virtio-mem "$fixture/workspace") = "$fixture/workspace/pve-virtio-mem" ]]
[[ $(PROJECT_TMP_BASE="$fixture/base" project_tmp_resolve pve-virtio-mem) = "$fixture/base/pve-virtio-mem" ]]
[[ $(PROJECT_TMP_BASE="$fixture/base" PROJECT_TMP_ROOT="$fixture/base/pve-virtio-mem" project_tmp_resolve pve-virtio-mem) = "$fixture/base/pve-virtio-mem" ]]
if PROJECT_TMP_BASE="$fixture/base" PROJECT_TMP_ROOT="$fixture/other/pve-virtio-mem" project_tmp_resolve pve-virtio-mem; then
    echo 'conflicting override accepted' >&2; exit 1
fi
if PROJECT_TMP_BASE=relative project_tmp_resolve pve-virtio-mem; then
    echo 'relative base accepted' >&2; exit 1
fi
ln -s "$fixture/original" "$fixture/pve-virtio-mem"
if PROJECT_TMP_ROOT="$fixture/pve-virtio-mem" project_tmp_resolve pve-virtio-mem; then
    echo 'symlink root unexpectedly accepted' >&2; exit 1
fi
echo 'project path isolation and external mapping passed'
