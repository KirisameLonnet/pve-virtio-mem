# Preview limitations and acceptance criteria

Live validation has now passed in an isolated Linux Q35 guest with GPU/VFIO
passthrough. A complete RAM grow/shrink cycle changed actual QMP allocation,
guest MemTotal and host cgroup consumption consistently. The removable pool
was fully unplugged and the corresponding host RAM was released.

PVE allocation and guest-use statistics were correct. Re-enabling native shares
resulted in pvestatd automatically growing the virtio-mem device. Basic GPU
compute smoke tests passed after shrinking.

These are basic live acceptance results, alongside adapter, package-lifecycle,
real-package-copy and paused QEMU checks. They do not establish compatibility
with every application, active pinned-memory workload or lifecycle operation.

These results cover guest-capacity-changing hotplug. The separate
[transparent-reclamation prototype](../experimental/transparent/README.md)
has only isolated TCG acceptance; it establishes no live VFIO, current PVE
or desktop workload support.

When validating another deployment or workload, check the following:

- A full stop/start boots with the original disks, firmware and networking.
- Linux detects virtio_mem and onlines new RAM with the intended policy.
- Grow and shrink requests change actual query-memory-devices size and guest
  MemTotal. A requested size alone is not evidence of completion.
- Shrinking decreases host cgroup memory.current and QEMU RSS/PSS, with the
  GPU still attached. Separate fixed/shared/device memory and QEMU overhead.
- GPU display and representative CUDA allocations survive repeated resizing.
- PVE reports maximum, actual allocation and guest consumption consistently.
- Native automatic scheduling responds correctly under controlled host pressure.
- Normal guest reboot, cold start, package upgrade and removal behave correctly.

Pinned or unmovable guest pages may prevent a complete shrink. Neither QEMU
nor this adapter guarantees the minimum is reachable under every workload.
A stats-only fix would not resolve VFIO-pinned host RAM, so both must be measured.

Live migration, HA recovery, suspend-to-disk, snapshots containing VM state,
hotplugging the memory device itself, multiple NUMA nodes, hugepages, virtio-fs,
confidential VMs and non-Linux guests are outside the validated scope.
Dynamic KVM memory slots and configurable block sizes are future work.
Requested hugepages, DIMM hotplug, virtio-fs and SEV/TDX compatibility work is
tracked in the [roadmap](roadmap.md); none is enabled by the GUI addition.

The GUI and live manual-target decrease fix require new live acceptance.
Earlier live validation above predates these changes. Offline adapter tests
do not establish guest onlining or VFIO RAM reclamation for a new workload.

Software-copy tests: qemu-server 9.1.17 and 9.2.11 loaded with PVE dependencies;
apply twice and hash-verified rollback succeeded. QEMU 11.0 accepted a paused
TCG topology and requested-size updates. The paused guest intentionally did not
plug memory; this test makes no reclamation or GPU performance claim.

The full PVE Q35 command builder also accepted a synthetic opt-in configuration,
including the fixed RAM backend, virtio-mem device and balloon statistics device.
No real guest was started during that check.

The native memory editor was exercised in a browser with extracted
pve-manager 9.2.21, ExtJS and widget-toolkit assets and synthetic form data.
Loading, saving, disabling and validation passed. Native scheduler contract
tests use the unmodified AutoBalloon implementation with equivalent status
inputs; they do not establish identical guest hotplug latency.

## PCI device placement

The memory backend is constructed in the existing PVE memory builder, but the
virtio-mem PCI device is appended after all PVE devices and custom arguments.
QEMU can then allocate a free PCI address without taking an explicitly reserved
VGA or IVSHMEM slot. A paused QEMU regression covers both reservations.
