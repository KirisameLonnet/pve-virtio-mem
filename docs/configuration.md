# Configuration

The new opt-in property is `virtio-mem`, measured in MiB. The existing memory,
balloon and shares fields keep their PVE meanings:

| Property | Meaning |
| --- | --- |
| `memory` | Maximum RAM, including the removable pool |
| `virtio-mem` | Removable pool; fixed boot RAM is memory minus this value |
| `balloon` | Minimum target; must be between fixed boot RAM and maximum |
| `shares` | Native PVE scheduler weight; zero disables automatic adjustments |

Synthetic example for a **stopped disposable guest**:

```sh
qm set <vmid> --machine q35 --ostype l26 --numa 1 --sockets 1
qm set <vmid> --memory 16384 --virtio-mem 12288 --balloon 4096 --shares 1000
```

Boot RAM must be at least 1024 MiB. Memory values must be aligned to 2 MiB.
Keep the virtio-balloon device enabled for statistics; resizing commands are
translated to virtio-mem, so the balloon is not inflated at the same time.
The preview supports one virtual socket, one NUMA node and ordinary anonymous
RAM. It rejects DIMM memory hotplug, explicit numaN topology, hugepages,
virtio-fs and confidential-VM settings. Existing non-memory hotplug options
may remain enabled. Topology/pool changes require a full VM stop/start.

## Linux guest

Use a recent Linux kernel with CONFIG_VIRTIO_MEM, MEMORY_HOTPLUG and
MEMORY_HOTREMOVE (a current LTS kernel is recommended). Load `virtio_mem`
through the distribution's native module configuration if needed. Configure
memory onlining through the distribution's bootloader, for example:

```text
memhp_default_state=online memory_hotplug.online_policy=auto-movable memory_hotplug.auto_movable_ratio=301
```

Consult the [virtio-mem Linux guide](https://virtio-mem.gitlab.io/user-guide/user-guide-linux.html)
before selecting a policy. A large removable pool with a small boot base does
not imply all of that pool can always be removed. Unmovable or pinned guest
pages can delay or prevent reaching a requested minimum. Do not force all
added RAM into ZONE_MOVABLE without considering the workload's kernel memory.

## Host and devices

The initial implementation uses `memory-backend-ram,reserve=off,prealloc=off`,
2 MiB blocks and `dynamic-memslots=off`. Static KVM slots avoid requiring a
live vhost module reload, but lose the metadata savings and extra isolation
of dynamic slots. This is an explicit preview limitation. It does not disable
the QEMU/VFIO discard coordination mechanism.

The [QEMU guide](https://virtio-mem.gitlab.io/user-guide/user-guide-qemu.html)
describes VFIO DMA-map limits and dynamic slots. Large pools may need a larger
block size or additional VFIO mapping capacity; this preview exposes neither
as a config option. Do not assume arbitrary pool sizes or every passthrough
device are supported.

PVE scheduling remains gradual and driven by host pressure, not immediate
application demand. A minimum is not an idle-memory target. Configure a
minimum sufficient for the guest workload and measure actual reclamation.
