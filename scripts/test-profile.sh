#!/bin/bash
# Pre-release CPU/allocation captures are deleted immediately after analysis.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-virtio-mem-env.sh"
pve_virtio_mem_env tests
command -v valgrind >/dev/null || { echo 'Install valgrind before running profiled tests' >&2; exit 1; }
# Keep the complete functional gate. Profile the runtime adapter separately:
# tracing every deployment-fixture Python/patch child measures process startup
# repeatedly, rather than the Perl code used by PVE's memory status loop.
bash "$ROOT/tests/virtio-mem/run.sh"
RUN_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
REPORT="$PVE_VIRTIO_MEM_RUN_DIR/profiles/$RUN_ID"
mkdir -p "$REPORT"
SUMMARY="$ROOT/docs/profiling/latest.md"
mkdir -p "$(dirname "$SUMMARY")"
# Delete complete/probe captures even when a test or annotation fails.
trap 'rm -rf "$REPORT"' EXIT
{
    git -C "$ROOT" rev-parse HEAD
    git -C "$ROOT" status --short
    valgrind --version
    bash --version | sed -n '1p'
    python3 --version
    printf 'Commands: Callgrind CPU pass; Memcheck allocation pass; both trace children\n'
    printf 'CPU: instrumented instruction events (not wall-clock samples); allocations: full xtree events\n'
    printf 'Valgrind tools cannot run together: equivalent workload captured twice as a pair\n'
    printf 'Workload: runtime adapter tests; complete functional suite passed first\n'
} > "$REPORT/receipt.txt"
set +e
valgrind --tool=callgrind --trace-children=yes \
    --callgrind-out-file="$REPORT/cpu.%p" --log-file="$REPORT/callgrind.%p.log" \
    perl "$ROOT/tests/virtio-mem/adapter.t" > "$REPORT/cpu-tests.log" 2>&1
cpu_rc=$?
valgrind --tool=memcheck --trace-children=yes --xtree-memory=full \
    --xtree-memory-file="$REPORT/heap.%p" --log-file="$REPORT/memcheck.%p.log" \
    perl "$ROOT/tests/virtio-mem/adapter.t" > "$REPORT/tests.log" 2>&1
heap_rc=$?
rc=$((cpu_rc || heap_rc))
set -e
printf 'CPU pass: %s; heap pass: %s\n' "$cpu_rc" "$heap_rc" >> "$REPORT/receipt.txt"
printf 'Temporary profiling capture: %s\n' "$REPORT"
tail -8 "$REPORT/tests.log"
# Analyse the largest processes before deleting all raw captures. Whole-tree
# annotation takes longer than tests and adds no value for tiny helper processes.
python3 "$ROOT/scripts/analyse-profiles.py" "$REPORT" > "$REPORT/profile-summary.log"
{
    printf '# Latest pre-release profiling\n\n'
    printf 'Workload: runtime adapter tests; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes. Complete functional suite passed separately.\n'
    printf 'CPU pass: %s; allocation pass: %s.\n' "$cpu_rc" "$heap_rc"
    git -C "$ROOT" rev-parse HEAD
    valgrind --version
    cat "$REPORT/profile-summary.md"
    printf '\nScope: adapter tests include Perl and Test::More startup; deployment fixtures are not profiled.\n'
    printf 'No PVE runtime or guest performance claim; CPU is instruction events, not wall time.\n'
    printf 'Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.\n'
} > "$SUMMARY"
exit "$rc"
