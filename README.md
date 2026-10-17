# pve-virtio-mem

Proxmox VE 的 virtio-mem 内存集成。它为 Linux Q35 虚拟机添加可移除内存池，
接入 PVE 原生内存编辑器和 AutoBalloon 调度。

## 功能

- 在 PVE 网页的 **VM → 硬件 → 内存** 对话框中配置 `virtio-mem (MiB)`。
- 使用 QEMU virtio-mem 在线增加或移除客户机内存。
- 使用 PVE 的 `balloon`、`shares`、宿主内存预算和状态采样。
- 客户机空闲内存降至最低内存的 25% 或更低时，压力扩容可在一个调度周期内达到
  PVE 计算出的目标；普通 balloon VM 和缩容保留原生步长。
- `shares=0` 保留手动调整模式。

客户机看到的是已经接入的内存。`memory` 表示最大容量，包含固定启动内存和
virtio-mem 池；设置上限不会预先增加客户机的 `MemTotal`。扩容依赖 PVE 状态采样，
大块分配可能先于新内存上线。内存热插、上线和移除都是异步操作。

透明空闲页回收和按需复用不属于当前 Debian 包。相关 QEMU/Linux 原型位于
[`experimental/transparent`](experimental/transparent/README.md)，不代表生产支持。

## 要求

- Proxmox VE 9。
- Linux Q35 客户机，单 socket、单 NUMA 节点。
- `virtio_mem`、内存热插拔和热移除支持。
- 启用 balloon 统计设备，并配置客户机自动上线新内存。
- 普通匿名 RAM。

当前不支持 hugepages、DIMM 内存热插拔、virtio-fs、显式多 NUMA 和 SEV/TDX。
QEMU、qemu-server 和 pve-manager 的版本要求见[安装文档](docs/installation.md)。

## 安装

项目目前提供开发预览包。从 [GitHub Actions](https://github.com/KirisameLonnet/pve-virtio-mem/actions/workflows/ci.yml)
下载生成的 `.deb`，在每个可能运行该 VM
的 PVE 节点安装：

```sh
apt install ./pve-virtio-mem_*.deb
```

安装程序会校验并修改 PVE 管理模块和网页资源，并通过 dpkg 文件触发器在升级后重放
补丁。它不会重启运行中的 VM。完整的安装、升级和移除流程见
[安装文档](docs/installation.md)。

## 配置

网页配置入口：**VM → 硬件 → 内存 → 编辑 → virtio-mem (MiB)**。

命令行示例（VM 需停止）：

```sh
qm set <vmid> --machine q35 --ostype l26 --numa 1 --sockets 1
qm set <vmid> --memory 16384 --balloon 4096 --virtio-mem 12288 --shares 1000
```

| 参数 | 说明 |
| --- | --- |
| `memory` | 最大内存，单位 MiB |
| `virtio-mem` | 可移除内存池大小；`0` 禁用 |
| `balloon` | 最低内存目标，不得低于固定启动内存 |
| `shares` | PVE 调度权重；`0` 禁用自动调整 |

固定启动内存为 `memory - virtio-mem`。内存值按 2 MiB 对齐。池大小和内存拓扑修改
需要完整关机再启动；网页不会修改客户机内核参数。

Linux 客户机需要启用 `virtio_mem`、内存热插拔和热移除。可使用以下内核参数自动
上线可移动内存：

```text
memhp_default_state=online memory_hotplug.online_policy=auto-movable memory_hotplug.auto_movable_ratio=301
```

更多参数和客户机限制见[配置说明](docs/configuration.md)与[网页操作](docs/webui.md)。

## 运行中调整

`virtio-mem` 池大小决定 VM 的容量范围，不能在运行中修改。运行中的扩缩容通过
`balloon` 目标完成，目标范围是固定启动内存到 `memory`。

手动模式下，在网页中打开 **VM → 硬件 → 内存 → 编辑**，先将 **Shares** 设为 `0`
并保存，再次打开对话框修改 **Minimum memory** 后保存。此时 Minimum memory 是在线
调整目标；`virtio-mem (MiB)` 只用于修改池大小，需要完整关机再启动。Shares 非零时，
Minimum memory 是自动调度的下限，由 pvestatd 决定实际目标。

手动调整时先关闭 AutoBalloon：

```sh
qm set <vmid> --shares 0
qm set <vmid> --balloon 8192   # 在线增长到 8 GiB
qm set <vmid> --balloon 4096   # 在线缩回到 4 GiB
```

上例假设固定启动内存为 4 GiB，且最大内存至少为 8 GiB。`balloon` 和内存池数值均以
MiB 表示，并按 2 MiB 对齐。缩容受客户机可移动页限制；不可移动或被固定的页面会使
请求保持在较高容量。

恢复自动调度：

```sh
qm set <vmid> --shares 1000
```

PVE 会在后续 `pvestatd` 采样中按 shares 和宿主内存预算调整目标。virtio-mem 客户机
空闲内存不高于最低内存的 25% 时，压力扩容可直接使用本轮计算出的增长目标。

检查配置和实际接入量：

```sh
qm config <vmid> | grep -E '^(memory|balloon|shares|virtio-mem):'
pvesh get /nodes/<node>/qemu/<vmid>/status/current --output-format json
```

状态中的 `balloon`/实际内存反映已经接入的容量，不是尚未完成的请求。客户机内可用
`grep -E 'MemTotal|MemAvailable' /proc/meminfo`确认内存上线；热插和移除都是异步的。

## 开发

```sh
make test
make deb
```

源码布局、测试环境和隔离实验见[开发文档](docs/development.md)。架构说明见
[architecture.md](docs/architecture.md)，第三方来源和许可证见
[provenance.md](docs/provenance.md)。
