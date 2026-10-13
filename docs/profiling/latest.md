# Latest pre-release profiling

Workload: runtime adapter tests; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes. Complete functional suite passed separately.
CPU pass: 0; allocation pass: 0.
490e955cf522fe46163e4fa02b84d5a6e2a61302
valgrind-3.22.0
CPU captures: 1; allocation captures: 1.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 194691217:  perl tests/virtio-mem/adapter.t

## Largest allocated bytes/objects processes
* 17727692 / 84190: perl tests/virtio-mem/adapter.t

Scope: adapter tests include Perl and Test::More startup; deployment fixtures are not profiled.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.

Review: ordinary-VM arguments retain their original reference, and ordinary VMs
queue no additional memory-device request. Enabled VMs queue one per status
cycle. Measurements include the interpreter and test harness, so they do not
isolate per-VM runtime latency or justify further allocation tuning.

[Profiling run](https://github.com/KirisameLonnet/pve-virtio-mem/actions/runs/38345340988)
and [Debian build](https://github.com/KirisameLonnet/pve-virtio-mem/actions/runs/38345338076)
passed for this runtime implementation.
