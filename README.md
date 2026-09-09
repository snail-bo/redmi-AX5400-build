# ImmortalWrt build for Redmi AX5400

面向 **Xiaomi Redmi AX5400（RA74）** 的 ImmortalWrt 自动编译方案，目标平台为 `qualcommax/ipq50xx`，集成 PassWall，并默认仅保留 SingBox 核心。

## 硬件信息

| 项目 | 值 |
|---|---|
| 型号代码 | RA74（请以机身标签为准） |
| SoC | Qualcomm IPQ5018 双核 Cortex-A53 @ 1.0 GHz |
| 内存 / 闪存 | 512 MiB DDR3L / 128 MiB NAND |
| 无线 | IPQ5018 2.4 GHz（2x2）+ QCN9024 5 GHz（4x4） |
| 构建目标 | `qualcommax/ipq50xx` / `xiaomi_redmi-ax5400` |

> Redmi AX6000、AX6S 和 AX3200 使用不同平台，不能使用本仓库固件。刷错固件可能导致设备变砖。

## 目录结构

```text
.github/
├── openwrt-build-packages.txt
└── workflows/immortalwrt_qualcommax_ipq50xx.yml
immortalwrt/qualcommax/ipq50xx/xiaomi_redmi-ax5400/
├── config.seed
└── diy/diy.sh
```

## 自动构建

工作流名称为 **Build ImmortalWrt for Redmi AX5400**：

- 使用 `immortalwrt/immortalwrt` 的固定提交，确保构建可复现。
- 推送 ImmortalWrt 设备配置、共享依赖清单或工作流修改时触发。
- 每月 1 日和 16 日北京时间 08:30 定时构建。
- 也可在 GitHub Actions 页面手动运行。
- 使用官方设备 profile，设备无线驱动、固件和 BDF 由 profile 自动选入。
- 集成 PassWall，默认仅编译 SingBox，并使用 nftables 透明代理方案。
- 使用标准 ath11k，不包含 NSS Wi-Fi offload。

构建成功后会创建 Release，标签格式为：

```text
immortalwrt-ax5400_<日期>_<运行序号>
```

主要固件产物：

```text
*-qualcommax-ipq50xx-xiaomi_redmi-ax5400-initramfs-factory.ubi
*-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-sysupgrade.bin
```

首次使用前，请在仓库的 **Settings → Actions → General** 中确认工作流可运行，并允许工作流写入仓库内容，以便创建 Release。

## 网络注意事项

固件默认 LAN 地址为 `192.168.1.1`。如果 WAN 上级主路由也使用 `192.168.1.0/24`，WAN 与 LAN 子网冲突会导致转发异常。刷机后应先把本机 LAN 改为其他网段，例如 `192.168.2.1/24`，再连接 WAN。

WAN 接入可提供 DHCP 的上级路由器时，WAN 协议应设置为 DHCP 客户端，并确认 WAN 物理端口已分配到 `wan` 网络。

## 刷机

1. 使用 [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher) 为原厂系统开启 SSH。原厂固件版本需满足该工具的支持要求。
2. 备份全部分区，并将备份保存到安全位置。
3. 先启动或刷入 `initramfs-factory.ubi` 过渡镜像。
4. 进入 ImmortalWrt 后执行：

   ```sh
   sysupgrade -n -v /tmp/<firmware>-squashfs-sysupgrade.bin
   ```

此设备采用 UBI rootfs。不要跳过 initramfs 过渡步骤，也不要在未核对设备型号、分区布局和启动槽状态时直接写入闪存。

## 更新上游版本

为了保证结果可复现，工作流不会自动跟随上游最新提交。升级时应：

1. 更新工作流中的 ImmortalWrt 固定提交。
2. 更新 `diy.sh` 中 feeds 和 PassWall 的固定提交。
3. 手动运行一次工作流，检查配置校验、包来源校验和固件打包结果。
4. 核对 Release 中记录的源码版本与预期一致。

## 常见问题

| 现象 | 检查方向 |
|---|---|
| WAN 获得地址但无法访问上级网络 | 检查 WAN/LAN 是否使用相同子网、默认路由、DNS 和防火墙区域 |
| PassWall 缺少 SingBox | 检查 PassWall packages feed 是否成功加载，以及固定提交是否仍包含对应包 |
| 无线接口不存在或无法启动 | 检查 ath11k 固件、`ipq-wifi-xiaomi_redmi-ax5400` BDF 和设备型号 |
| Go 软件包编译失败 | 检查 runner 的磁盘与内存，并减少并行任务数 |
| 固件体积过大 | 从 `config.seed` 移除不需要的 LuCI 应用或代理组件 |

## 致谢

[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) · [PassWall](https://github.com/Openwrt-Passwall/openwrt-passwall) · [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
