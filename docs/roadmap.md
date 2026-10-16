# Planned compatibility work

These features are requested follow-up work, not current support. Existing
guards remain until each combination has an implementation and acceptance
results. Continue to reuse native PVE scheduling and QEMU memory management.

## Transparent physical-page reclamation

The product target is constant guest-visible configured capacity, demand-driven
allocation up to that capacity when host resources permit, and automatic
redistribution of idle physical pages without manual resize steps. The current
virtio-mem backend implements hotplug and does not meet that target.

Necessary QEMU and guest-kernel changes are in scope. The opt-in
[source port](../experimental/transparent/README.md) now targets QEMU 11 and
Linux 6.18, retaining the native buddy allocator with a shared shadow bitmap.
Its constant-capacity TCG reclaim/reuse test passes, including native
allocation/free initialization. The VFIO exclusion remains active; DMA
coordination, the Proxmox patch series and native soft-policy/statistics
integration are unfinished. This does not replace the packaged backend.

Acceptance must additionally show that another isolated VM can consume the
released host RAM, that reallocating guest pages promptly restores safe CPU
and DMA mappings, and that live GPU data and workloads survive repeated
cycles. Do not infer success from a configured maximum, a QMP target, fixed
minimum/maximum values, or guest counters alone.

## Other compatibility work

| Feature | Implementation and acceptance requirements |
| --- | --- |
| hugepages | Select a compatible QEMU backend and block alignment; validate host reservation, real page release and VFIO DMA mapping limits separately for each page size. |
| DIMM memory hotplug | Separate changes to fixed/DIMM capacity from resizing the virtio-mem pool; account for memory slots, NUMA, pending configuration and native hotplug lifecycle. |
| virtio-fs | Integrate the shared-memory backend and vhost-user discard coordination; verify filesystem I/O and data integrity through repeated grow/shrink cycles. |
| SEV/TDX | Establish support in the relevant QEMU/KVM private-memory and hotplug interfaces first; implement and validate each confidential-VM technology separately. Support is conditional on upstream capabilities. |

Each feature needs backend/API validation, GUI constraints, guarded package
upgrade/rollback checks and live guest tests. For VFIO combinations, actual
guest allocation and host RAM reclamation must both be measured; successful
builds or requested-size changes alone are insufficient. Do not expose an
unsupported combination merely by removing its rejection check.
