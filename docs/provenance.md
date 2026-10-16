# Provenance and retained reuse

`pve-virtio-mem` is an independent Q35 memory integration fork of
[rcarmo/pve-microvm](https://github.com/rcarmo/pve-microvm). The original Git
history and author attribution are retained. The current tree no longer ships
that project's machine builder, OCI/template tools, guest init, dedicated kernel,
filesystem-sharing tools, UI or operating guides. Historical versions remain
in Git rather than duplicated as current documentation or package changelog.

## What remains from pve-microvm

| Current component | Retained source or design | Current use |
| --- | --- | --- |
| `tools/VirtioMem.pm` | Memory construction derived from `MicroVM.pm` | Fixed boot RAM plus removable pool for the native Q35 builder; native target/statistics adaptation |
| `tools/pve-virtio-mem-patch` | Preflight, backup, checksum and revert lifecycle model | A scoped implementation for five explicit PVE integration patches, with durable retry/rollback state |
| `tools/lib/project-tmp.sh` | Inherited generic project-root resolver | Ownership/symlink checks and portable development scratch selection |
| `tools/pve-virtio-mem-env.sh`, `tests/virtio-mem/paths.sh` | Adapted environment wrapper and path tests | Fork-specific caches/runs; unused image-chroot and legacy kernel-path interfaces removed |
| `debian/`, build/profile helpers | Packaging and test-isolation approach | This fork's package lifecycle and disposable test/build/profile data |

None requires the `pve-microvm` package at runtime. The Debian conflict is
intentional because both projects modify overlapping PVE source files.
No upstream early-boot patch service or custom scheduler is retained.

## Native PVE code

The unified patches in `patches/` contain qemu-server and pve-manager context.
`tests/virtio-mem/fixtures/` contains native AutoBalloon and memory-editor test
excerpts. These remain attributed to Proxmox and use AGPL-3.0-or-later, with
[the license text](../LICENSES/AGPL-3.0-or-later.txt). PVE continues to own
scheduling, API permissions, QMP transport, polling and VM lifecycle.

## Separate research prototype

The optional transparent-reclaim experiment fetches upstream QEMU 11, Linux
6.18 and [LLFree](https://github.com/luhsra/llfree-c) at exact revisions in
[`sources.json`](../experimental/transparent/sources.json). The local source
patches port the device/shared bitmap from
[HyperAlloc QEMU](https://github.com/luhsra/hyperalloc-qemu) and
[HyperAlloc Linux](https://github.com/luhsra/hyperalloc-linux); their exact
research revisions are also recorded. The Linux port retains the native buddy
allocator rather than importing the research allocator replacement. These are
separate experimental sources, not pve-microvm components or dependencies of
the Debian plugin. They are not included in the development `.deb`.
The source patches follow the QEMU/Linux GPL-2.0 terms; permissive notices
embedded in the original source remain intact. LLFree retains its MIT license
in the fetched source tree. Upstream attribution and Git history are retained.

See [the experiment](../experimental/transparent/README.md) for the authors'
paper, source ports, build receipt and narrowly scoped acceptance result.

## Licenses

The fork retains [Apache-2.0](../LICENSE) for the upstream tools and original
fork code unless a file or the copyright manifest specifies otherwise.
PVE patch/test context remains AGPL-3.0-or-later. The local Linux patch is
covered by GPL-2.0-only, as is the aggregate QEMU source port; its license text is in
[`LICENSES/GPL-2.0-only.txt`](../LICENSES/GPL-2.0-only.txt).
[`debian/copyright`](../debian/copyright) records the applicable file groups.
Removing unused sources does not remove their authors from Git history or
relicense retained code.
