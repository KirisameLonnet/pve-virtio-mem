# pve-virtio-mem

为 Proxmox VE 的 Linux Q35 虚拟机提供 virtio-mem 热插拔，让客户机在需要时
在线增加 RAM，并在可移动页允许时把空闲 RAM 归还宿主机。配置入口接入 PVE
原生内存编辑器，调度继续使用 PVE 的 balloon、shares 和宿主内存预算。

| 能力 | 状态 | 客户机可见容量 |
| --- | --- | --- |
| virtio-mem 在线扩缩容 | 开发预览版 | 随实际接入和移除的内存变化 |
| 透明空闲页回收与按需复用 | 独立实验，尚未集成 | 实验目标是保持配置容量不变 |

## 工作方式

PVE 的 `memory` 是最大容量，包含固定启动内存和 virtio-mem 池。客户机只会看到
已经实际接入的内存；保存一个较大的上限不会让客户机预先认为全部容量可用。

启用 virtio-mem 后，PVE 仍按原生 shares 和宿主预算计算每台 VM 的目标。采样到
客户机空闲内存不高于配置最低内存的 25% 时，该 VM 可在一个 PVE 调度周期内增长到
原生策略允许的目标，不受常规每周期 100 MiB 增长步长限制。普通 balloon VM 和缩容
仍使用 PVE 原有步长；`shares=0` 关闭自动调整，保留手动模式。

触发依赖 PVE 状态采样，并非应用发出的内存请求或预留。突然的大块分配可能在新内存
上线前失败。客户机启动时只看到已接入容量，因此要求较大初始 `MemTotal` 的软件需要
足够的启动／最低内存。内存热插、客户机上线和移除均可能异步完成。

## 要求

- Proxmox VE 9；具体 QEMU、qemu-server 和 pve-manager 兼容范围见[安装文档](docs/installation.md)。
- Linux Q35 客户机，单 socket、单 NUMA 节点，启用 balloon 统计设备。
- 客户机内核支持 `virtio_mem`、内存热插拔和热移除，并配置新内存自动上线。
- 普通匿名 RAM。hugepages、DIMM 内存热插拔、virtio-fs、显式多 NUMA 和 SEV/TDX
  不在当前支持范围内。

透明空闲页回收是独立实验，尚未集成到 Debian 插件中。插件不提供恒定的客户机可见容量，
也不实现宿主回收页面的透明复用。实验状态和限制见
[后续工作](docs/roadmap.md)及[已知问题](docs/known-issues.md)。

## 安装

目前提供开发预览包，尚无稳定版。可从
[GitHub Actions](https://github.com/KirisameLonnet/pve-virtio-mem/actions/workflows/ci.yml)
下载 `.deb`，然后在每个可能运行该 VM 的 PVE 节点安装：

```sh
apt install ./pve-virtio-mem_*.deb
```

安装会校验并补丁化 PVE 管理文件和网页编辑器，不会重启正在运行的 VM。安装、升级、
兼容检查和移除步骤见[安装维护](docs/installation.md)。该集成不是 Proxmox 官方插件 API。

## 配置

网页中打开 **VM → 硬件 → 内存 → 编辑**，设置 `virtio-mem (MiB)`。最小内存和共享权重
仍在 PVE 原生高级选项中。`virtio-mem` 是可热插拔池大小；固定启动内存等于
`memory - virtio-mem`。

例如，下面为一台停止状态的 VM 配置 4–16 GiB：

```sh
qm set <vmid> --machine q35 --ostype l26 --numa 1 --sockets 1
qm set <vmid> --memory 16384 --balloon 4096 --virtio-mem 12288 --shares 1000
```

| 参数 | 含义 |
| --- | --- |
| `memory` | 最大内存，包含固定内存和可热插拔池，单位 MiB |
| `virtio-mem` | 可热插拔池大小，`0` 表示禁用 |
| `balloon` | PVE 最低内存目标，不得低于固定启动内存 |
| `shares` | PVE 原生调度权重；`0` 表示手动管理 |

Linux 客户机需启用 `virtio_mem` 及内存热插拔／移除，并设置内存上线策略，例如：

```text
memhp_default_state=online memory_hotplug.online_policy=auto-movable memory_hotplug.auto_movable_ratio=301
```

池大小和内存拓扑变更需要完整关机再启动。网页只配置热插拔设备，不会替 VM 修改
Q35、NUMA、socket 或客户机启动参数。更多约束见[配置说明](docs/configuration.md)和
[网页操作](docs/webui.md)。

## 开发

```sh
make test
make deb
```

测试、打包和隔离实验说明见[开发文档](docs/development.md)。本项目由
[pve-microvm](https://github.com/rcarmo/pve-microvm) 分叉，仅保留当前集成实际复用的
源码、补丁管理和构建工具；保留的第三方来源与许可证见[来源说明](docs/provenance.md)。
