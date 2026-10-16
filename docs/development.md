# Development

This repository builds the Q35 memory integration described in the [README](../README.md).
Retained upstream components are listed in [provenance](provenance.md).

## Source layout

| Path | Responsibility |
| --- | --- |
| `tools/VirtioMem.pm` | Memory topology, native target translation and actual-allocation statistics |
| `patches/` | Guarded qemu-server and native memory-editor integration |
| `tools/pve-virtio-mem-patch` | Package provenance checks, durable apply/revert journal and repair CLI |
| `debian/` | Package metadata, installation/removal hooks and dpkg file triggers |
| `tools/pve-virtio-mem-env.sh`, `tools/lib/project-tmp.sh` | Development scratch and cache isolation |
| `tests/virtio-mem/` | Adapter, native scheduler, package lifecycle, GUI and path checks |
| `scripts/` | Isolated package build, real-package checks and pre-release profiling |
| `experimental/transparent/` | Separate source/build and TCG acceptance prototype |

The Debian package installs the adapter, five integration patches, patch manager
and package documentation. It does not build or install the research QEMU/kernel.
There is no legacy kernel or OCI/template build target.

## Functional and package checks

On Debian/Ubuntu, install `git build-essential dpkg-dev debhelper fakeroot perl
python3 patch nodejs`. Add `valgrind` for pre-release profiling.

```sh
make test
make deb
```

The functional suite runs without PVE services or guest access. It checks native
scheduler decisions, command translation, frontend behavior, package lifecycle
guards, path ownership/isolation and transparent-acceptance false-positive guards.
`make deb` stages and tests a copy under the project build root.

For a non-PVE macOS development host, `PROJECT_TMP_BASE=/private/tmp make test`
uses the real temp directory. Build Debian packages in an isolated Linux environment.

To exercise official PVE package copies without changing the running host:

```sh
bash scripts/check-package.sh <qemu-server.deb> <pve-manager.deb>
```

This extracts the packages into disposable staging, applies twice, checks the
native editor, and verifies rollback against package hashes. With matching PVE
Perl dependencies installed, it also loads the staged modules. The optional
`tests/virtio-mem/qemu-smoke.py` accepts a QEMU executable for a paused topology
and PCI-placement check; a paused test proves no guest allocation or reclamation.

## Profiling and cleanup

```sh
make test-profile
```

Before release, the complete functional gate is followed by equivalent adapter
workloads under Callgrind and Memcheck. Analyse CPU instruction events and
cumulative allocated bytes/objects, then tune avoidable work only when evidence
supports it. Test-interpreter totals do not establish per-VM runtime performance.
The script writes concise conclusions to `docs/profiling/latest.md` and deletes
raw captures, annotations and disposable logs after use, including failures.
Ordinary development tests need not be profiled on every run.
Run this from a Git checkout so the summary can record its source revision.

The generic resolver chooses the canonical `pve-virtio-mem` root using
`PROJECT_TMP_BASE` or `PROJECT_TMP_ROOT`, with ownership and symlink checks.
Caches, build copies and runs stay beneath that root. Stop owning jobs before
removing completed disposable scratch; preserve intentional release assets.
Guest runtime paths are separate from host development scratch.

## Transparent reclamation experiment

`make transparent-build` and `make transparent-test` are explicit opt-in targets.
See [the prototype README](../experimental/transparent/README.md) for dependencies,
source locks, negative control and cleanup. These launch a new isolated TCG guest
with a matching research kernel. They do not access PVE guests or establish
VFIO safety, current PVE compatibility or production support.

## CI and review

The CI workflow runs functional tests, builds and lists the development package,
and retains its intentional `.deb` artifact. A manually dispatched pre-release
workflow runs profiling and retains only conclusions. Both dispose build scratch.
Neither workflow currently publishes a tagged release.

Keep source changes and public reports scoped to the product. Use synthetic
fixtures; never publish managed-host identities, workload details or raw logs.
Live tests and deployment require their own authorised scope and acceptance gates.
