# Architecture and reuse

The fork reuses pve-microvm's Debian packaging approach, delegated memory
construction, project scratch resolver and guarded patch/backup/revert model.
Upstream history, license and author attribution are retained. The fork does
not install its microvm machine builder, custom kernel, OCI helpers or UI.

QEMU, the Linux virtio_mem driver and VFIO implement memory hot(un)plug and
page disposal. Proxmox retains VM lifecycle, API permissions, QMP transport,
asynchronous polling, RRD updates and the AutoBalloon scheduling policy.

Four narrow source patches connect these existing components:

1. `QemuServer/Memory.pm` delegates only opted-in memory construction.
2. `QemuServer/Monitor.pm` translates native balloon commands into QMP qom-set.
3. `QemuServer.pm` registers the pool option and adds query-memory-devices to
   its existing QMP queue, before query-balloon. Statistics use actual plugged
   memory, never merely requested memory. The existing guest total/free
   counters are retained.
4. `API2/Qemu.pm` classifies the new option as VM.Config.Memory.

The adapter builds one fixed boot backend and one sparse virtio-mem backend
on NUMA node zero. It subtracts fixed boot RAM from each native total-RAM
target. It does not modify pvestatd or PVE::AutoBalloon and has no event loop.

The package lifecycle tool runs GNU patch with zero fuzz and uses Python's
standard library for checksums, locking and a durable rollback journal. It
runs only during installation, upgrade, removal or an explicit repair.
Debian-provided checksums distinguish pristine package replacements from
administrator edits; all files are preflighted before any source edit.

This is source-level integration, not an officially supported PVE plugin API.
The standard Q35 builder still owns disks, network, firmware, PCI passthrough,
serial devices and display devices. Their live behavior needs separate guest
validation; successful Perl loading alone does not prove it.
