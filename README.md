# pve-virtio-mem

为 Proxmox VE 9 的标准 Q35 Linux 虚拟机提供 virtio-mem 内存热插拔，
让带 GPU／PCI 直通的 VM 在缩容时释放宿主 RAM。内存目标、最小值和共享权重
沿用 PVE 原生管理，插件将调整请求转换为 QEMU virtio-mem 操作。

## 当前能力与目标

| 路径 | 状态 | 客户机看到的内存 |
| --- | --- | --- |
| Debian 插件：virtio-mem 热插拔 | 已实现；开发预览版 | 随实际接入容量变化 |
| 透明空闲页回收与按需复用 | 隔离实验原型 | 实验中保持配置容量不变 |

**当前插件尚未实现透明借还。** 固定最小内存等于最大内存也不会实现这一能力。
透明回收实验需要配套的 QEMU 和客户机内核；其 TCG 分配、回收和复用测试已通过，
尚未接入当前 PVE／VFIO 路径。详见[实验说明](experimental/transparent/README.md)
和[后续工作](docs/roadmap.md)。

现有热插拔接入包含：

- 原生网页内存编辑器中的 `virtio-mem (MiB)` 字段、待生效显示和撤销。
- PVE 原生 `balloon`／`shares` 调度目标转换，以及实际接入内存统计。
- 安装校验、持久补丁、dpkg 升级触发器和带哈希校验的卸载回滚。

## 安装

要求 PVE 9、QEMU 10 或以上、qemu-server 9.1.17 或以上；兼容测试版本及限制见
[安装文档](docs/installation.md)。虚拟机需使用 Linux、Q35、单 socket、单 NUMA
节点，并启用 balloon 统计设备。客户机需有 `virtio_mem` 和内存热插拔／移除支持。

从 [GitHub Actions](https://github.com/KirisameLonnet/pve-virtio-mem/actions/workflows/ci.yml)
下载并解压开发包，在 PVE 节点安装：

```sh
apt install ./pve-virtio-mem_*.deb
```

安装会校验并修改 PVE Perl 模块及原生网页内存编辑器。运行中的 VM 不会被重启；
刷新浏览器加载编辑器。升级、兼容失败和卸载步骤见[安装维护](docs/installation.md)。

## 配置

在 **虚拟机 → 硬件 → 内存 → 编辑** 设置池大小；最小内存和共享权重在原生高级选项中。

| 参数 | 含义，容量单位为 MiB |
| --- | --- |
| `memory` | 最大容量，包含固定内存和可热插拔池 |
| `virtio-mem` | 可热插拔池；固定内存为 `memory - virtio-mem`；`0` 表示禁用 |
| `balloon` | 最低内存目标，不能低于固定内存 |
| `shares` | 原生调度权重；`0` 关闭自动调整 |

以下为一台**已关机的测试 VM** 配置 4–16 GiB 内存：

```sh
vmid=9000 # 替换为测试 VM 编号
qm set "$vmid" --machine q35 --ostype l26 --numa 1 --sockets 1
qm set "$vmid" --memory 16384 --balloon 4096 --virtio-mem 12288 --shares 1000
```

客户机还需配置内存上线策略，例如在其内核启动参数中加入：

```text
memhp_default_state=online memory_hotplug.online_policy=auto-movable memory_hotplug.auto_movable_ratio=301
```

池大小及内存拓扑修改需要完整关机再启动。启动分配、原生调度和客户机热插拔均有
各自的完成时机；保存上限不代表实际容量已经接入。详见[配置语义](docs/configuration.md)
和[网页操作](docs/webui.md)。

## 支持边界

基础 Linux Q35 GPU/VFIO 热插拔与宿主页回收已有验证；结果仅覆盖所测组合。
当前拒绝 hugepages、DIMM 内存热插拔、virtio-fs、显式多 NUMA 拓扑和 SEV/TDX。
迁移、HA、带运行状态的快照及更广泛 GPU 工作负载仍需验证。固定页或不可移动页
可能阻止完成缩容，详见[限制和验收范围](docs/known-issues.md)。

## 源码与开发

```sh
make test
make deb
# 发布前：分析 CPU／分配行为并自动删除原始捕获
make test-profile
```

依赖、目录布局、包副本验证和隔离实验入口见[开发文档](docs/development.md)。

本项目从 [rcarmo/pve-microvm](https://github.com/rcarmo/pve-microvm) 分叉，
当前源码只保留本项目实际使用的内存构建来源、补丁管理模型、打包和通用目录解析器。
旧 microvm 机型、OCI／模板工具、客户机 init、专用内核构建、UI 及操作指南已移除；
历史提交、许可证和作者归属保留。逐项复用及第三方许可见[来源说明](docs/provenance.md)。

`pve-microvm` 不是运行依赖；两者会修改同一批 PVE 文件，因此软件包保留冲突声明。
