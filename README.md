# OpenWrt e1915674ab build for Redmi AX5400

面向 **Xiaomi Redmi AX5400（RA74）** 的固定版本自动构建。源码锁定到已在实机确认 WAN 正常的 OpenWrt 提交 `e1915674ab327a25a1dbe48644471a905c962085`，集成 LuCI、PassWall，并默认只选择 SingBox 核心。

## 版本依据

已知正常运行的设备报告为：

```text
OpenWrt SNAPSHOT r34603+1-e1915674ab
Linux 6.12.89
LuCI Master 26.140.75290~c707d21
kmod-qca-nss-dp 6.12.89.2026.03.13~6a5c4716
kmod-qca-ssdk   6.12.89.2025.05.30~446db12b
```

本构建锁定公开可确认的 OpenWrt 基础提交 `e1915674ab` 和 LuCI 提交 `c707d21`。版本字符串中的 `+1` 表示原固件在该提交上还有一个未公开或本地提交，因此不能仅凭版本字符串逐字节复刻；本仓库不会虚构该提交。

该版本仍使用实机验证正常的 QCA NSS-DP/SSDK 数据路径，没有切换到出现 WAN `NO-CARRIER` 现象的 IPQ5018 DWMAC 路径：

```text
WAN：wan → dp1/eth0
LAN：lan1/lan2/lan3 → dp2/eth1
```

## 硬件信息

| 项目 | 值 |
|---|---|
| 型号代码 | RA74（请以机身标签为准） |
| SoC | Qualcomm IPQ5018 双核 Cortex-A53 @ 1.0 GHz |
| 内存 / 闪存 | 512 MiB DDR3L / 128 MiB NAND |
| 无线 | IPQ5018 2.4 GHz（2x2）+ QCN9024 5 GHz（4x4） |
| 构建目标 | `qualcommax/ipq50xx` / `xiaomi_redmi-ax5400` |

> Redmi AX6000、AX6S 和 AX3200 使用不同平台，不能使用本仓库固件。

## 目录结构

```text
.github/
├── openwrt-build-packages.txt
└── workflows/openwrt_qualcommax_ipq50xx.yml
openwrt/qualcommax/ipq50xx/xiaomi_redmi-ax5400/
├── config.seed
└── diy/diy.sh
```

## 自动构建

工作流名称为 **Build OpenWrt e1915674ab for Redmi AX5400**：

- 固定 OpenWrt 源码及全部 feeds 提交，避免定时任务悄然改变内核或驱动。
- 使用 QCA NSS-DP 和 QCA-SSDK；不启用完整 NSS driver/ECM。
- 使用官方 AX5400 设备 profile，自动加入无线驱动、固件和 BDF。
- 集成 PassWall，使用 nftables，默认仅编译 SingBox。
- 推送 `openwrt/**`、共享依赖清单或工作流修改时触发。
- 每月 1 日和 16 日北京时间 08:30 定时构建。
- 也可在 GitHub Actions 页面手动运行。
- 构建后检查 initramfs、sysupgrade 以及 sysupgrade 内部 kernel/rootfs 的尺寸；超限时不发布 Release。

Release 标签格式：

```text
openwrt-e191-ax5400_<日期>_<运行序号>
```

主要产物：

```text
*-qualcommax-ipq50xx-xiaomi_redmi-ax5400-initramfs-factory.ubi
*-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-sysupgrade.bin
config.build
source-versions.txt
sha256sums.txt
```

首次使用前，请在仓库的 **Settings → Actions → General** 中确认工作流可以运行，并允许工作流写入仓库内容，以便创建 Release。

## 网络配置

默认 LAN 地址为 `192.168.1.1`。如果上级路由器也使用 `192.168.1.0/24`，请先将本机 LAN 改为其他网段，例如 `192.168.2.1/24`。

WAN 应使用 DHCP 客户端并绑定 DSA 设备 `wan`。不要创建 `br-wan`，也不要把底层 conduit `eth0` 直接分配给 WAN。

正确关系为：

```text
wan 网络 → wan DSA 端口 → dp1/eth0
lan 网络 → br-lan → lan1/lan2/lan3 → dp2/eth1
```

## 刷机

1. 使用 [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher) 为原厂系统开启 SSH。
2. 备份全部 MTD 分区和启动环境。
3. **先使用 `initramfs-factory.ubi` 测试启动**，确认 LAN、WAN、Wi-Fi、分区布局和重启均正常。
4. 只有在具备串口或 XMiR 恢复能力、并完成上述验证后，才考虑执行：

   ```sh
   sysupgrade -n -v /tmp/<firmware>-squashfs-sysupgrade.bin
   ```

必须使用 `-n`，不要继承 X-WRT、ImmortalWrt 或其他网络栈的旧配置。

## PassWall

- PassWall feeds 排在其他 feeds 之前，确保 SingBox、geodata 等同名包来自 PassWall 源。
- 默认启用 SingBox，禁用 Xray 和其他可选代理核心。
- 不要同时运行其他透明代理服务。
- 如果代理启用后出现连接绕过或异常，先关闭软件/硬件 flow offloading 和 NSS ECM 加速再测试。

曾有大体积 `sysupgrade.bin` 导致设备无法启动的记录，所以“Actions 构建成功”不等于“可以直接刷写”。首次产物应视为测试版；没有恢复手段时不要刷 `sysupgrade.bin`。

## 版本升级

升级 OpenWrt 或 feeds 时应：

1. 更新工作流中的 `OPENWRT_REF`。
2. 更新 `diy.sh` 中所有 feed 的固定提交。
3. 手动运行工作流，确认包来源、NSS/SSDK、无线包与固件产物校验通过。
4. 先通过 initramfs 实机验证 WAN 收发，再发布 sysupgrade 固件。

## 致谢

[OpenWrt](https://github.com/openwrt/openwrt) · [PassWall](https://github.com/Openwrt-Passwall/openwrt-passwall) · [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
