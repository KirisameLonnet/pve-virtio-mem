# Transparent reclamation prototype

This opt-in source/build experiment evaluates **constant guest-visible RAM with
automatic physical-page reclamation and demand-driven reuse**. It is separate
from the packaged virtio-mem hotplug adapter. No production PVE backend, GUI
switch or replacement `/usr/bin/kvm` is installed by these commands.

The prototype reuses [HyperAlloc QEMU](https://github.com/luhsra/hyperalloc-qemu),
[HyperAlloc Linux](https://github.com/luhsra/hyperalloc-linux) and
[LLFree](https://github.com/luhsra/llfree-c). Their exact commits and matching
allocator ABI are pinned in [sources.json](sources.json); no moving branches
or SSH submodule URLs are used during builds. The upstream licenses and source
history remain in the fetched checkouts. See the authors' [EuroSys 2025 paper](https://www.sra.uni-hannover.de/Publications/2025/hyperalloc-eurosys25/wrenger_25_eurosys.pdf).
The local [init-section patch](patches/linux-init-section.patch) annotates an
upstream memblock-only constructor; section mismatch errors remain enabled.
Applied patch hashes are recorded alongside the source revisions in the build.

HyperAlloc's automatic **soft** reclamation releases idle physical frames
while leaving them available to the guest allocator. Its separate classic
hard-balloon target is not used by this experiment. The QEMU device provides
DMA population/discard coordination; this must be validated with real devices
before any VFIO support claim for this fork.

## Build and isolated acceptance

Use a disposable Linux x86_64 or aarch64 development environment with Git, Clang/LLVM/LLD,
make, Ninja, Python 3.9+, Python venv/tomli/packaging, pkg-config, GLib/pixman,
zlib, ELF/OpenSSL development headers, bison, flex and bc. For example, Debian
bookworm provides these through `build-essential git clang llvm lld python3
python3-venv python3-tomli python3-packaging ninja-build pkg-config
libglib2.0-dev libpixman-1-dev libfdt-dev zlib1g-dev libelf-dev libssl-dev bison flex bc`.

```sh
make transparent-build
# Use the exact project-owned build directory printed by that command:
make transparent-test TRANSPARENT_BUILD_DIR=<absolute-build-directory>
```

The default build uses one job. `TRANSPARENT_BUILD_JOBS` can increase that
within the development environment's memory budget. The minimal kernel is
only for the synthetic test guest; it is not a desktop kernel configuration.
The QEMU executable targets the build host; LLVM cross-compiles the x86_64
guest kernel and init on aarch64, avoiding emulated compiler processes.
Neither command installs kernels, binds PCI devices or accesses PVE guests.

Acceptance boots a new diskless, networkless TCG guest. The freestanding init
program twice allocates and touches approximately 90% of guest MemTotal,
holds and checks live data, frees it, then allocates it again. The host runner
requires unchanged MemTotal, preserved allocated data, successful reuse, and
a material QEMU RSS drop after each free. Only a concise result is returned;
guest logs are discarded after diagnosis. Fetched sources and build outputs
stay in the owning build directory only while the current analysis needs them.
For a negative control:

```sh
bash tools/pve-virtio-mem-env.sh --exec transparent \
    python3 experimental/transparent/accept.py <absolute-build-directory> --no-auto-reclaim
```

Allocation should still complete, but physical-reclaim validation must fail
and return a nonzero exit code. Unchanged capacity and successful allocation
alone are insufficient.

## Observed isolated result

With the locked sources, init-section patch and LLVM 14, an x86_64 TCG fixture
configured with 512 MiB reported an unchanged MemTotal of 504016 KiB throughout
both cycles. Each cycle allocated/touched 463470592 bytes, preserved the live
page patterns and fresh-page zeroing, and released 450887680 bytes of QEMU RSS
after freeing. This checks the soft-reclaim mechanism in the synthetic guest;
the automatic-reclaim-disabled control completed the same guest workload but
was correctly rejected with zero RSS reclaimed in the first round.
This is not a VFIO, PVE or desktop workload result. Raw build/test captures and
matching disposable binaries are removed after analysis.

## Required before PVE integration

The upstream research trees are based on QEMU 8.2 and Linux 6.1. They are not
drop-in replacements for current Proxmox QEMU or a desktop distribution kernel.
Port the allocator/device and DMA coordination to supported versions, retain
PVE's required QMP interfaces, and make backend capability checks fail closed.
Keep the existing hotplug path available and the two backends mutually exclusive.
Verify guest feature negotiation before enabling reclamation. Keep configured
capacity, guest-visible capacity, policy targets and resident physical memory
distinct in status/QMP handling. Reusing PVE scheduling must not silently turn
soft reclaim into the research device's hard-balloon operation. Preserve
VFIO discard guards and coordinate DMA unmap/populate before releasing or
reusing pages; globally bypassing the discard restriction is not a solution.

The isolated TCG test cannot validate VFIO DMA safety, GPU/CUDA workloads,
multiple-VM redistribution, current PVE compatibility, migration or production
stability. Those remain required acceptance gates. No controller, cron job or
early-boot patch service is introduced; physical-page handling belongs in the
QEMU/guest mechanism and PVE retains VM management and host allocation policy.
