# Web memory configuration

After installing the package, refresh the PVE browser tab and open
**VM → Hardware → Memory → Edit**. The native dialog contains a
**virtio-mem (MiB)** field directly below Memory.

- Memory is the total maximum, including the removable pool.
- virtio-mem is the removable pool. Set it to zero to disable the option.
- Minimum memory and Shares remain in the native advanced options.
- Keep Ballooning Device enabled for statistics.

For example, Memory 16384, minimum 4096 and virtio-mem 12288 define a
4–16 GiB VM with 4 GiB of fixed RAM. The editor checks memory relationships
and 2 MiB alignment. Linux, Q35, NUMA, one socket and disabled DIMM memory
hotplug must also be configured; the dialog does not silently change them.

Pool edits use the native VM configuration API and VM.Config.Memory
permission. The hardware memory row shows the pool in both current and
pending values. Native Revert includes the pool together with the other
memory settings. A pool change requires a full shutdown and start; saving
the dialog does not restart the guest.

The create-VM wizard is unchanged. Configure an existing stopped VM before
its first virtio-mem boot. This fork does not package the upstream Create
µVM button or other microvm UI modifications.

See [configuration](configuration.md) for startup/scheduling semantics and
guest prerequisites. pve-manager upgrades reapply the guarded bundle patch
through dpkg file triggers; unknown administrator changes are not overwritten.
