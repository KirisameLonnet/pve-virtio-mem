# pve-virtio-mem contributor instructions

## Scope and architecture

Active packaged implementation: `tools/VirtioMem.pm`, `patches/`,
`tools/pve-virtio-mem-patch` and `debian/`. Tests live in `tests/virtio-mem/`.
The independent `experimental/transparent/` source/build prototype is opt-in
and is not installed by the Debian package. Legacy microvm code and guides
have been removed; retained upstream reuse is listed in `docs/provenance.md`.
Retain upstream attribution, licenses and Git history.

Reuse native PVE scheduling and QEMU memory management. Do not add a custom
scheduler, cron job or early-boot patch service. Persistent checksum-guarded
patches and dpkg file triggers maintain the installed integration. Changes
must remain reversible, idempotent and fail closed on unknown source edits.

The product target is constant guest-visible configured capacity with
transparent idle-page reclamation and demand-driven reuse. The packaged
virtio-mem hotplug backend does not yet implement that experience. Necessary
QEMU and guest-kernel source changes are authorised for development; the
isolated prototype is not a production replacement. Do not claim transparent
VFIO support from a build, fixed capacity, a TCG test or requested-size alone.
Live VFIO acceptance must measure actual guest allocation, host page release,
DMA safety and representative GPU operations separately.

Do not contact other agents. Honor explicit execution pauses; this policy
permits no automatic restart of paused jobs or unsolicited remote deployment.

<!-- RUI-PROFILE-LIFECYCLE-20261005 -->
## Current profiling and cleanup rule — supersedes older text below

Rui's explicit rule: **profile and tune during pre-release tests; remove profiling data immediately after analysis/use.** Ordinary development tests do not require profiling on every run. Targeted diagnostic profiling is optional when useful and follows the same disposal rule.

- During pre-release verification, capture CPU and heap/allocation behaviour, analyse hotspots and tune avoidable allocations/repeated work. Compare equivalent workloads without weakening correctness/security/numerical contracts. For Go, inspect CPU, alloc_space and alloc_objects; coverage alone is not profiling.
- Keep captures and matching artifacts only while the current analysis needs them. Once used, immediately delete raw profiles, traces, matching test binaries, temporary fixtures and disposable logs, including failed/probe artifacts after diagnosis. Retain only concise conclusions and important measurements/limitations. Do not keep indefinite raw archives or copy them into exports/reports/evidence to evade cleanup.
- Remove all completed disposable cache/build/test/run data promptly. Never delete files still in use: finish or safely pause the owning job and clean at a safe boundary. Preserve source, installed toolchains, durable datasets/checkpoints and intentional release assets. Minimise disk usage; no random exports or redundant snapshots.
- This rule overrides **every conflicting older paragraph in this file and linked local guidance**, including “profile every test”, “unprofiled tests prohibited”, “retain all raw evidence”, “never delete profiles” and cleanup exclusions based only on an evidence/profiles directory name. Update helper/CI cleanup behaviour accordingly; do not weaken pre-release analysis.
- Existing no-agent-contact and execution-pause rules remain unchanged. This policy grants no unsolicited coordination or automatic job restart.
<!-- /RUI-PROFILE-LIFECYCLE-20261005 -->

## Public communication and managed-infrastructure privacy

Treat managed test infrastructure as potentially containing customer information.
Do not publish internal hostnames, node/guest names or IDs, addresses, domains,
topology, capacity/utilisation, workload identities, storage/backup locations,
recovery paths, operational incidents, credentials or other internal details
("inside baseball") in issues, comments, PRs, commits, release notes, repository
docs, screenshots, attachments or CI artifacts. Testing permission is not
publication permission; previous public disclosures do not grant permission to
repeat them.

Public reports should contain only the product defect, relevant public software
versions, minimal sanitised reproduction, fix, scoped test outcomes and user
recovery guidance. Say "an isolated test guest" or "a test host" instead of naming
managed systems. Keep migration/deployment logistics and unrelated applications
in private operational records, not public product reports. Explicit user
approval is required before disclosing any infrastructure-specific detail.

Before publishing, review both the payload and linked documents/artifacts for
these details; sanitise logs, paths and identifiers without changing technical
facts. Prefer synthetic fixtures. Never paste raw managed-host logs or configs.
If details were published, remove them from current content and report the
remaining exposure privately; do not rewrite Git history or delete other
people's comments without explicit authorisation.

## Scratch and build isolation

Resolve canonical project `pve-virtio-mem` with `tools/lib/project-tmp.sh`
through `tools/pve-virtio-mem-env.sh`, before replacing `TMPDIR`.
`PROJECT_TMP_BASE` selects a base; `PROJECT_TMP_ROOT` selects its complete
project-named root. Both must agree. Relative, empty, unowned and symlink
roots fail. The resolver captures `PROJECT_ORIGINAL_TMPDIR` once.

CI chooses runner temp, inherited temp, then system temp. Local execution
chooses a usable `/workspace/tmp`, then system temp. Explicit valid overrides
win. On macOS use a real absolute base such as `PROJECT_TMP_BASE=/private/tmp`
when `/tmp` is a symlink. Never depend on a host-global workspace helper.

Keep caches under `cache/`, builds under `build/`, and temporary runs under
`runs/<purpose>/run.XXXXXX/`. The helper creates and exports TMPDIR/TMP/TEMP,
XDG, Bun, npm and Python caches beneath this tree. `make deb` stages a copy
under `build/deb/`; generated Debian files must not appear in the checkout.
`make clean CONFIRM_IDLE=yes` removes only project scratch after jobs stop;
preserve intentional release assets and apply the profiling disposal rule.

## Verification

Run `make test` and `make deb` for changes to the package, tests or build tools.
Use `make test-profile` before release: analyse paired CPU/allocation captures,
record concise conclusions, and dispose captures and matching fixtures.
Ordinary development checks do not require profiling on every run.

Use `scripts/check-package.sh <qemu-server.deb> <pve-manager.deb>` for isolated
real-package apply-twice, frontend and hash-verified rollback checks. PVE module
loading needs matching PVE dependencies; successful generic mocks do not
replace it. The optional paused QEMU check and transparent guest experiment
have their own explicit limits in `docs/development.md`.

Stage any authorised live rollout on one non-critical test guest first.
Verify package state and PVE services, cold boot, guest onlining, grow/shrink,
host RAM reclamation and GPU data integrity before broader deployment. Do not
restart existing guests or change managed workloads as part of a source-only
review. Avoid partial PVE upgrades and never bypass package checksum guards.

## Git, releases and documentation

- Work on `main` for local development; use a review branch for a requested PR.
- Keep commits outcome-focused. Do not rebase or rewrite published history.
- For a release, update `debian/changelog`, tag `vX.Y.Z`, push the commit/tag
  and use the project's actual CI/release workflow. Do not assume that a tag
  publishes assets: current workflows build development packages and run
  manually requested pre-release checks.
- Installation examples must be version-agnostic. After publishing a release,
  validate one non-critical node before expanding an authorised rollout.
- Update README and relevant architecture, configuration, installation,
  limitations and development docs with behaviour changes. Cite retained
  dependencies in `docs/provenance.md`; do not restore unused upstream guides.
