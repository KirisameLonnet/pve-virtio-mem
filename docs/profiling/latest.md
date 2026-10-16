# Latest pre-release profiling

Workload: runtime adapter tests; Callgrind instructions and Memcheck cumulative bytes/objects in paired passes. Complete functional suite passed separately.
CPU pass: 0; allocation pass: 0.
Source base: `8cca92becbf1da3d2de1392c83eeef3cd1a40c63`; working tree includes the repository-scope cleanup.
valgrind-3.19.0
CPU captures: 1; allocation captures: 1.
CPU units are instrumented instructions, not latency. Heap units are cumulative bytes and objects. Paired runs execute the same test workload.

## Largest cpu instructions processes
* 187982531: perl tests/virtio-mem/adapter.t

## Largest allocated bytes/objects processes
* 17755124 / 91799: perl tests/virtio-mem/adapter.t

Scope: adapter tests include Perl and Test::More startup; deployment fixtures are not profiled.
No PVE runtime or guest performance claim; CPU is instruction events, not wall time.
Equivalent paired workload; isolation preserved. Raw captures disposed after analysis.

Analysis: an additional equivalent diagnostic pair identified Perl parsing and
lexing among the largest self-CPU entries (10.05% and 2.68%). Heap call-tree
annotation did not resolve Perl allocation frames, so allocation conclusions
are limited to cumulative totals, not individual application functions.
The packaged adapter runtime is unchanged by this cleanup; there is no
measurement justifying a runtime allocation or scheduler change. No tuning
was inferred from interpreter/test-startup totals. This Linux aarch64 fixture
is not a latency or cross-architecture comparison with previous reports.
The diagnostic captures and annotations were also disposed immediately.
