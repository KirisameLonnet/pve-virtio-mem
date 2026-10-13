# Preview limitations and acceptance criteria

The current validation covers the Perl adapter, package lifecycle, actual
qemu-server package copies and a paused QEMU TCG smoke test. It does not yet
establish end-to-end VFIO memory reclamation or production safety.

Before using an enabled VM for real workloads, verify all of the following:

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

Software-copy tests: qemu-server 9.1.17 and 9.2.11 loaded with PVE dependencies;
apply twice and hash-verified rollback succeeded. QEMU 11.0 accepted a paused
TCG topology and requested-size updates. The paused guest intentionally did not
plug memory; this test makes no reclamation or GPU performance claim.

The full PVE Q35 command builder also accepted a synthetic opt-in configuration,
including the fixed RAM backend, virtio-mem device and balloon statistics device.
No real guest was started during that check.
