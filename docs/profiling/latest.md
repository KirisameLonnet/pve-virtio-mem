# Latest pre-release profiling

Workload: runtime adapter tests; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes. Complete functional suite passed separately.
CPU pass: 0; allocation pass: 0.
c8e06418203cb9233555dc05ed0683dc84ddee44
valgrind-3.24.0
CPU captures: 1; allocation captures: 1.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 191357373:  perl /tmp/pve-virtio-mem/build/profile-source/tests/virtio-mem/adapter.t

## Largest allocated bytes/objects processes
* 17975944 / 85115: perl /tmp/pve-virtio-mem/build/profile-source/tests/virtio-mem/adapter.t

Scope: adapter tests include Perl and Test::More startup; deployment fixtures are not profiled.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.

Analysis: the profiled worktree includes the GUI/native-parity changes.
Ordinary VM arguments retain their original reference and add no memory-device
query; enabled VMs add one query to the existing async queue. No new runtime
allocation or repeated scan was introduced by the physical-bound fix. The
interpreter/test-harness totals do not isolate per-VM latency or justify a
performance comparison across Valgrind versions. No further tuning was indicated.
