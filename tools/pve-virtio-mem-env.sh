#!/bin/bash
# Shared host-side scratch/cache layout. Guest /tmp mounts are unrelated.

pve_virtio_mem_env() {
    local path purpose=${1:?purpose required}
    [[ "$purpose" =~ ^[a-z0-9-]+$ ]] || { echo 'invalid scratch purpose' >&2; return 1; }
    # Vendored resolver: standalone in installed packages and hosted CI.
    local helper_dir root
    helper_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    source "$helper_dir/lib/project-tmp.sh"
    # Compatibility alias for existing project configuration; generic override wins.
    if [[ -z "${PROJECT_TMP_ROOT+x}" && -n "${PVE_VIRTIO_MEM_TMP_ROOT+x}" ]]; then
        export PROJECT_TMP_ROOT=$PVE_VIRTIO_MEM_TMP_ROOT
    fi
    root=$(project_tmp_resolve pve-virtio-mem) || return
    project_tmp_init "$root" || return
    export PROJECT_TMP_ROOT=$root PVE_VIRTIO_MEM_TMP_ROOT=$root
    export PVE_VIRTIO_MEM_TEST_DIR="$root/tests" PVE_VIRTIO_MEM_LOG_DIR="$root/logs"
    export PVE_VIRTIO_MEM_CACHE_DIR="$root/cache"
    export PVE_VIRTIO_MEM_BUILD_DIR="$root/build"
    mkdir -p "$root/runs/$purpose"
    # Reuse only an explicitly inherited run beneath this project's run tree.
    if [[ -z "${PVE_VIRTIO_MEM_RUN_DIR:-}" ]]; then
        PVE_VIRTIO_MEM_RUN_DIR=$(mktemp -d "$PVE_VIRTIO_MEM_TMP_ROOT/runs/$purpose/run.XXXXXX") || return
    fi
    [[ "$PVE_VIRTIO_MEM_RUN_DIR" = "$PVE_VIRTIO_MEM_TMP_ROOT/runs/"* && -d "$PVE_VIRTIO_MEM_RUN_DIR" && "$PVE_VIRTIO_MEM_RUN_DIR" != *'/../'* ]] \
        || { echo 'invalid inherited project run directory' >&2; return 1; }
    export PVE_VIRTIO_MEM_RUN_DIR
    project_path_usable "$PVE_VIRTIO_MEM_RUN_DIR" || return
    local temp_path="$PVE_VIRTIO_MEM_RUN_DIR/tmp"
    # Create before export: traced subprocesses use TMPDIR at process startup.
    for path in "$temp_path" "$root/cache/xdg" "$root/cache/bun" "$root/cache/npm" "$root/cache/python"; do
        project_path_usable "$path" || { echo "Unsafe child path: $path" >&2; return 1; }
        mkdir -p "$path"
    done
    export TMPDIR="$temp_path" TMP="$temp_path" TEMP="$temp_path"
    export XDG_CACHE_HOME="$root/cache/xdg" BUN_INSTALL_CACHE_DIR="$root/cache/bun"
    export npm_config_cache="$root/cache/npm" PYTHONPYCACHEPREFIX="$root/cache/python"
    export PYTHONDONTWRITEBYTECODE=1

}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    set -euo pipefail
    [[ "${1:-}" = --exec && $# -ge 3 ]] || { echo "Usage: $0 --exec PURPOSE COMMAND [ARG...]" >&2; exit 1; }
    purpose=$2; shift 2
    pve_virtio_mem_env "$purpose"
    exec "$@"
fi
