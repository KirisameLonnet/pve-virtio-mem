# Installation and package lifecycle

This is an experimental development package. Basic live GPU/VFIO RAM
reclamation, native scheduling and CUDA/SHMEM operation have passed acceptance
checks in a Linux Q35 guest. Start another deployment with a disposable guest;
see the documented scope before using broader lifecycle operations.

Build on Debian with `make deb`, then install the resulting local package using
`apt install ./pve-virtio-mem_*.deb`. CI artifacts are also available from the
repository's Actions page. There is no stable release yet.

The package requires PVE 9, QEMU 10 or newer and qemu-server 9.1.17 or newer.
Package-copy compatibility was tested with qemu-server 9.1.17 and 9.2.11 only;
a version constraint is not a guarantee that future source layouts will work.
The frontend patch and browser fixture were tested with pve-manager 9.2.21.
It conflicts with pve-microvm because both edit the same PVE source files;
that package is not a dependency. See [provenance](provenance.md).

The development `.deb` installs the hotplug integration only. The separate
[transparent experiment](../experimental/transparent/README.md) requires
matching QEMU/guest-kernel sources and is not installed by this package.

## What installation does

1. Install the small Perl adapter and unified backend/web editor patches.
2. Verify PVE source against the installed Debian package checksums.
3. Preflight every patch with zero fuzz before modifying any PVE file.
4. Journal the originals and SHA-256 hashes in `/var/lib/pve-virtio-mem`.
5. Apply patches and refresh existing PVE API/proxy/status services.

Running guests are not restarted. Existing VMs without `virtio-mem` keep their
native memory builder and balloon commands. Package installation changes PVE
Perl files and the pve-manager JavaScript bundle, so this is not an official
Proxmox extension API. Refresh the browser after installation to load the
new **Hardware → Memory → Edit → virtio-mem (MiB)** field.

The edits persist across boots. Debian file triggers reapply them when
qemu-server or the pve-manager JavaScript bundle is upgraded. No early-boot
patch service or package hold is used.
Unknown edits or incompatible upstream changes fail package configuration
before writing patches. Resolve the version mismatch and rerun
`dpkg --configure -a`; do not bypass checksum checks.

Inspect state with `pve-virtio-mem-patch status`. An interrupted apply can be
retried with `pve-virtio-mem-patch apply`; the journal distinguishes originals
from patched files. File-by-file replacement is not a filesystem-wide atomic
transaction: do not start guests during package maintenance.

## Removal

Shut down enabled VMs normally. Remove `virtio-mem` from their configuration
with `qm set <vmid> --delete virtio-mem`, and resolve any snapshots retaining
the option. Fully stop/start before expecting the original memory topology.
Then remove the package using apt. The removal hook refuses to proceed while
positive virtio-mem options remain in cluster guest configs or snapshots.

Rollback verifies all file hashes before restoring anything. If an administrator
or another package modified a managed file, reconcile it first; the tool will
not overwrite it with a stale backup. A failed installation may require
repairing qemu-server from its matching official package before retrying.

Install the same tested package on every potential cluster destination before
enabling the option. Live migration, HA and saved-state restore are not yet
validated; do not use them with enabled VMs in this preview.
