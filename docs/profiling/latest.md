# Latest pre-release profiling

Workload: runtime adapter tests; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes. Complete functional suite passed separately.
CPU pass: 0; allocation pass: 0.
19bfbd7b518f21e29624fab773ddc995ffa91c73
valgrind-3.22.0
CPU captures: 1; allocation captures: 1.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 193857659:  perl tests/virtio-mem/adapter.t

## Largest allocated bytes/objects processes
* 17680606 / 83945: perl tests/virtio-mem/adapter.t

Scope: adapter tests include Perl and Test::More startup; deployment fixtures are not profiled.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.

Review: the adapter's ordinary-VM command path returns the original argument
reference, and ordinary VMs enqueue no extra memory-device request (covered by
tests). Enabled VMs enqueue one request per status cycle. The measurements
include the test harness and interpreter; they do not isolate a per-VM latency
or justify further allocation tuning. No custom runtime polling process exists.

[Profiling run](https://github.com/KirisameLonnet/pve-virtio-mem/actions/runs/38344433811)
passed after the full functional test gate.
[Debian package build](https://github.com/KirisameLonnet/pve-virtio-mem/actions/runs/38343797945)
passed for the same runtime implementation; later changes only affect profiling
and documentation.
