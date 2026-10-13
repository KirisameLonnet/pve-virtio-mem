# pve-virtio-mem

为 **Proxmox VE 的普通 Q35 Linux VM** 接入 QEMU `virtio-mem`，用于探索
PCI/GPU 直通场景下的宿主内存回收。项目派生自
[rcarmo/pve-microvm](https://github.com/rcarmo/pve-microvm)，保留上游历史和署名。

**状态：开发预览（alpha），尚未完成真实 GPU 直通的内存回收验收。**
软件包副本测试和 QEMU 命令测试通过，不代表生产兼容性已验证。

## 如何工作

- 继续使用 PVE 的 `pvestatd` / `PVE::AutoBalloon` 调度算法、shares 和内存上下限。
- 为显式启用的 VM 把 `balloon` 目标转换为 `virtio-mem` 的 `requested-size`。
- 用 QMP 实际已接入的内存容量修正分配统计，保留 balloon 驱动提供的客户机统计。
- 保留普通 Q35、UEFI 和原有设备构建流程；无需换成 microvm 机型。
- 使用 Debian 软件包、升级文件触发器及可验证回滚。
  **不安装自定义开机服务、定时任务或内存调度守护进程。**

PVE 原生调度主要响应宿主内存压力。最低值是下限，空闲时不保证立即降至最低；
有空余宿主 RAM 时，原算法可能增加分配。内存热拔除也可能受客户机不可移动页阻碍。

## 开发与验证

```sh
make test
make deb
# macOS 的 /tmp 是符号链接，使用解析后的临时目录：
PROJECT_TMP_BASE=/private/tmp make test
```

Debian 构建需要 `build-essential`、`debhelper`、`dpkg-dev`、Perl、Python 3 和 GNU patch。
生成的包位于项目独立临时目录的 `build/deb/` 下；GitHub CI 提供构建产物。

| 检查 | 已验证范围 |
| --- | --- |
| 适配器 | 33 项检查：上下限、对齐、普通 VM 不变、异步统计和请求转换 |
| 安装生命周期 | 7 项测试：幂等、回滚、升级、中断恢复、管理员改动及备份损坏保护 |
| 真实包副本 | qemu-server 9.1.17、9.2.11：补丁、模块加载、回滚校验 |
| QEMU | 11.0：暂停的 TCG 实例接受设备及 QMP 请求；未启动客户机 |
| GPU 直通 RAM 回收 | **待测**：客户机驱动、实际回收量、GPU 工作负载及重启 |

## 文档

- [安装、升级与卸载](docs/installation.md)
- [参数与客户机配置](docs/configuration.md)
- [架构及复用边界](docs/architecture.md)
- [已知限制与验收](docs/known-issues.md)

原 microvm 内核、OCI 工具和 UI 等源文件保留用于历史及复用参考，**不进入此项目的安装包**。
[原上游 README](docs/upstream-readme.md) 与未改写的 microvm 文档仅描述上游产品。

Apache-2.0；原上游署名保留。PVE 源码补丁的上下文来自 Proxmox
[qemu-server](https://git.proxmox.com/?p=qemu-server.git)，该部分遵循其原有许可。
