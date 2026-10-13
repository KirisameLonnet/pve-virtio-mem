# pve-virtio-mem

为 Proxmox VE 的 Q35 Linux 虚拟机添加 virtio-mem 支持的 Debian 软件包。
让带 GPU／PCI 直通的虚拟机在缩容时释放宿主 RAM。

普通 balloon 无法解除 VFIO 固定的 RAM 映射。本项目将 PVE 的内存调整请求
转换为 virtio-mem 热插拔，调度仍由 PVE 原生的 `pvestatd` 和 `shares` 管理。
宿主内存充裕时可以扩容，内存紧张时缩容；最低内存是缩容下限。

## 安装

要求 PVE 9、QEMU 10 或以上、qemu-server 9.1.17 或以上。
虚拟机使用 Q35、单 socket、单 NUMA 节点；客户机需要 Linux 5.19 或以上及 `virtio_mem` 驱动。
不能与 `pve-microvm` 同时安装。

从 [GitHub Actions](https://github.com/KirisameLonnet/pve-virtio-mem/actions/workflows/ci.yml)
下载并解压构建产物，在 PVE 节点安装其中的 `.deb`：

```sh
apt install ./pve-virtio-mem_*.deb
```

软件包会校验、备份并修改 PVE 的 Perl 模块。升级补丁由 dpkg 触发器维护。
卸载和版本兼容说明见 [安装文档](docs/installation.md)。

## 配置

内存容量的单位为 MiB。

| 参数 | 含义 |
| --- | --- |
| `memory` | 内存上限，包含固定内存和 virtio-mem 池 |
| `virtio-mem` | 可热插拔的内存池；固定内存为 `memory - virtio-mem` |
| `balloon` | 最低内存目标，不能低于固定内存 |
| `shares` | PVE 自动调度权重；设为 `0` 关闭自动调度 |

以下示例为一台已关机的 Q35 Linux 虚拟机配置 4–16 GiB 内存，其中 12 GiB 由 virtio-mem 管理：

```sh
vmid=9000 # 修改为 VM 编号
qm set "$vmid" --numa 1 --sockets 1
qm set "$vmid" --memory 16384 --balloon 4096 --virtio-mem 12288 --shares 1000
```

在客户机的内核启动参数中加入：

```text
memhp_default_state=online memory_hotplug.online_policy=auto-movable memory_hotplug.auto_movable_ratio=301
```

配置完成后启动虚拟机。更改 virtio-mem 池大小需要完整关机再启动。
参数约束和内存在线策略见 [配置文档](docs/configuration.md)。

## 支持范围

已在 GPU/VFIO 直通 VM 上验证内存增减、宿主 RAM 回收、PVE 统计和原生自动调度。
缩容后的本地 CUDA 与 TensorFusion SHMEM 向量加法测试通过。

实机测试使用 PVE 9.2、QEMU 11、Linux 6.18、qemu-server 9.1.17；
qemu-server 9.2.11 已完成补丁应用、模块加载和回滚测试。

目前为开发版本。hugepages、DIMM 内存热插拔、virtio-fs 和 SEV/TDX 暂不支持；
迁移、HA 和带运行状态的快照尚未验证。客户机中的固定页或不可移动页可能阻止部分内存拔除。
详细记录见 [已知限制](docs/known-issues.md)。

## 开发

Debian 构建依赖：`build-essential`、`debhelper`、`dpkg-dev`、`fakeroot`、Perl、Python 3、GNU patch。

```sh
make test
make deb
```

`make deb` 会打印构建产物的输出路径。
macOS 使用 `PROJECT_TMP_BASE=/private/tmp make test`。
实现说明见 [架构文档](docs/architecture.md)。

## 来源与许可

派生自 [rcarmo/pve-microvm](https://github.com/rcarmo/pve-microvm)。
上游 microvm 相关源码保留在仓库中，不包含在本软件包内。

项目代码采用 [Apache-2.0](LICENSE)；包含 Proxmox 源码上下文的补丁采用
[AGPL-3.0-or-later](LICENSES/AGPL-3.0-or-later.txt)。
