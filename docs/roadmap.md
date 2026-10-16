# Planned compatibility work

These features are requested follow-up work, not current support. Existing
guards remain until each combination has an implementation and acceptance
results. Continue to reuse native PVE scheduling and QEMU memory management.

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
