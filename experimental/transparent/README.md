# Transparent reclamation source port

The product target is **constant guest-visible configured capacity, automatic
idle-page reclamation and immediate demand-driven reuse**. The Debian plugin
still implements virtio-mem hotplug, which changes guest capacity. These
opt-in sources are a separate development step, not a production backend.
They install no PVE changes, QEMU executable, kernel or service.

## Current implementation

The default build now uses upstream **QEMU 11.0.0 and Linux 6.18**, with exact
commits in [sources.json](sources.json) and local [source patches](patches/).
The device and shared bitmap derive from
[HyperAlloc QEMU](https://github.com/luhsra/hyperalloc-qemu),
[HyperAlloc Linux](https://github.com/luhsra/hyperalloc-linux) and
[LLFree](https://github.com/luhsra/llfree-c); research revisions are recorded in
the lock file. See the authors' [EuroSys 2025 paper](https://www.sra.uni-hannover.de/Publications/2025/hyperalloc-eurosys25/wrenger_25_eurosys.pdf).
Attribution and licenses are retained in the patch/source files and
[provenance](../../docs/provenance.md).

The kernel port **retains the native buddy allocator, per-CPU page lists and
memory accounting**. LLFree is a shadow availability bitmap, not the page
allocator. A successful free publishes availability after free-time hardening;
allocation reserves the exact frame selected by the native allocator and
synchronizes backing restoration before allocation-time initialization or
caller access. The research tree's replacement allocator, reclaim/accounting
changes, KVM host-kernel ioctls, DAX experiments and benchmarks are not imported.
The constructor remains `__init`; section-mismatch errors stay enabled.

The QEMU port leaves ordinary virtio-balloon compiled. The private shared ABI
requires a negotiated feature plus matching magic/version; an ordinary balloon
driver cannot silently negotiate this protocol. It is not a registered stable
virtio ABI. Hard balloon requests are rejected because removing pages behind
the native buddy allocator would corrupt its state. QMP status distinguishes
configured capacity and device-discarded bytes; discarded bytes are not QEMU RSS.
Unsupported migration and device hotplug are blocked.

**VFIO is still unsupported in this port.** QEMU's native
`ram_block_discard_require()` exclusion deliberately remains active, so pinned
RAM/VFIO combinations are rejected rather than bypassing discard protection.
The inherited RamDiscardManager code still needs a full audit/port of address
translation, DMA ordering, error recovery and lifetime handling, followed by
real-device acceptance. An API port or TCG pass does not establish DMA safety.

## Build and isolated acceptance

Use a disposable Linux x86_64 or aarch64 environment with Git, Clang/LLVM/LLD,
make, Ninja, Python 3.9+, Python venv/tomli/packaging, pkg-config, GLib/pixman,
zlib, ELF/OpenSSL development headers, bison, flex and bc. The port was tested
with LLVM 19 on Debian trixie. For example:

```sh
apt install build-essential git clang llvm lld python3 python3-venv \
    python3-tomli python3-packaging ninja-build pkg-config libglib2.0-dev \
    libpixman-1-dev libfdt-dev zlib1g-dev libelf-dev libssl-dev bison flex bc
make transparent-build
# Use the project-owned build directory printed by that command:
make transparent-test TRANSPARENT_BUILD_DIR=<absolute-build-directory>
```

The default is one build job; `TRANSPARENT_BUILD_JOBS` can increase it within
the environment's memory budget. The QEMU executable targets the build host;
LLVM cross-compiles the x86_64 kernel and init on aarch64. Exact source revisions
and applied patch hashes are written into the owning build directory.

The minimal guest kernel is not a desktop configuration. This experiment
requires a fixed supported CPU topology and one memory node. Its Kconfig
rejects unported combinations including memory hotplug, CMA, hugetlbfs, device
memory, compaction, PREEMPT_RT and page poisoning. These are acceptance gaps,
not production support claims or instructions to disable desktop protections.

Acceptance launches a new diskless, networkless TCG guest. It checks private
protocol/status negotiation and rejection of hard ballooning and migration.
The freestanding init twice allocates/touches approximately 90% of MemTotal,
checks live data and fresh-page zeroing, frees it, then reallocates. The runner
requires unchanged MemTotal, successful reuse and a material QEMU RSS drop in
both rounds. Two CPUs and native allocation/free initialization can be exercised:

```sh
bash tools/pve-virtio-mem-env.sh --exec transparent \
    python3 experimental/transparent/accept.py <absolute-build-directory> \
    --cpus 2 --hardened-init
```

For a negative control, replace those options with `--no-auto-reclaim`.
Allocation should complete, but physical-reclaim validation must fail and return
nonzero. Capacity markers, a requested target or successful allocation alone
are insufficient. Logs and disposable binaries are removed after analysis;
keep only concise measurements and limitations.

## Observed isolated result

With the locked QEMU 11/Linux 6.18 sources and LLVM 19, a 512 MiB TCG guest
completed two allocate/check/free/reuse cycles. Each allocation touched
463470592 bytes. The two-CPU run with `init_on_alloc=1 init_on_free=1` kept
MemTotal at 504164 KiB and released 455081984 and 455077888 bytes of QEMU RSS.
Protocol/status checks passed; hard ballooning and migration were rejected.
The one-CPU automatic-reclaim-disabled control completed both guest cycles
but correctly failed physical-reclaim validation with zero RSS drop.
These results establish neither PVE integration nor VFIO/GPU safety.

## Remaining production work

1. Complete and validate DMA discard/populate coordination before relaxing the
   native VFIO exclusion; exercise repeated reclaim/reuse with real devices.
2. Port onto the matching Proxmox QEMU patch series and retain required PVE QMP
   interfaces. A vanilla QEMU build is not a replacement PVE package.
3. Add a mutually exclusive, capability-checked PVE backend. Translate native
   policy targets into soft pressure/reclamation requests without a hard cap,
   changing MemTotal or fabricating allocated-memory statistics. Preserve the
   native scheduler and distinguish policy budget, guest capacity and residency.
4. Validate desktop kernel features, reset/teardown, guest memory pressure,
   multi-VM redistribution and representative GPU data integrity. Migration,
   snapshots, hugepages, DIMM hotplug, virtio-fs and SEV/TDX need separate work.

No GUI switch or production claim should precede these gates. No external
controller, cron job or early-boot patch service is introduced.
