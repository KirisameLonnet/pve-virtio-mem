# Architecture and reuse

This fork integrates only memory handling into the native Q35 builder.
Retained upstream source/design reuse and licenses are listed in
[provenance](provenance.md). Unused machine, image, kernel and UI tooling has
been removed from the current tree; original Git history remains intact.

QEMU, the Linux virtio_mem driver and VFIO implement memory hot(un)plug and
page disposal. Proxmox retains VM lifecycle, API permissions, QMP transport,
asynchronous polling, RRD updates and the AutoBalloon scheduling policy.

Five source patches connect these existing components:

1. `QemuServer/Memory.pm` delegates only opted-in memory construction.
2. `QemuServer/Monitor.pm` translates native balloon commands into QMP qom-set.
3. `QemuServer.pm` registers the pool option and adds query-memory-devices to
   its existing QMP queue, before query-balloon. Statistics use actual plugged
   memory, never merely requested memory. The existing guest total/free
   counters are retained. Native startup targets, scheduling eligibility,
   shares and rate limits are unchanged. Policy minimums remain PVE's concern;
   the command translator checks physical capacity so live manual target
   decreases can be applied before pending configuration is committed.
4. `API2/Qemu.pm` classifies the new option as VM.Config.Memory.
5. `pve-manager/js/pvemanagerlib.js` extends the native memory editor and
   hardware memory row, including pending/revert handling and permissions.
   This uses PVE's existing dialog and pending-configuration flow.

The adapter builds one fixed boot backend and one sparse virtio-mem backend
on NUMA node zero. The PCI device is appended after PVE devices and custom args
so QEMU's automatic address allocator respects their existing reservations. It subtracts fixed boot RAM from each native total-RAM
target. It does not modify pvestatd or PVE::AutoBalloon and has no event loop.

The package lifecycle tool runs GNU patch with zero fuzz and uses Python's
standard library for checksums, locking and a durable rollback journal. It
runs only during installation, upgrade, removal or an explicit repair.
Debian-provided qemu-server and pve-manager checksums distinguish pristine package replacements from
administrator edits; all files are preflighted before any source edit.

This is source-level integration, not an officially supported PVE plugin API.
The standard Q35 builder still owns disks, network, firmware, PCI passthrough,
serial devices and display devices. Their live behavior needs separate guest
validation; successful Perl loading alone does not prove it.

## Transparent reclamation experiment

Native scheduling decisions and transparent physical-page reclamation are
separate concerns. The existing adapter changes guest capacity through
virtio-mem. QEMU 11's VFIO type1 backend blocks uncoordinated page discard and
supports discard coordinated by RamDiscardManager; the ordinary balloon page
reporting path observes the discard restriction. See the upstream
[VFIO implementation](https://github.com/qemu/qemu/blob/v11.0.0/hw/vfio/container-legacy.c)
and [balloon implementation](https://github.com/qemu/qemu/blob/v11.0.0/hw/virtio/virtio-balloon.c).

The optional [transparent experiment](../experimental/transparent/README.md)
builds matching research QEMU/guest-kernel sources and checks constant capacity,
idle-page reclamation and reuse in a new TCG guest. It uses the provider's
automatic soft-reclamation mechanism rather than translating policy targets
into hard hotplug limits. It has no production PVE integration yet.
