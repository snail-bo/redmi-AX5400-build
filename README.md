# x-wrt-build

X-WRT 固件自动编译流水线。当前机型：**Xiaomi Redmi AX5400**（`qualcommax/ipq50xx`），集成 PassWall。

## 硬件核对

| 项目 | 值 |
|---|---|
| 型号代码 | **RA74**（机身标签核对） |
| SoC | Qualcomm IPQ5018 双核 Cortex-A53 @1.0GHz |
| 内存 / 闪存 | 512 MiB DDR3L / 128 MiB NAND |
| 无线 | IPQ5018 2.4G(2x2) + QCN9024 5G(4x4) |
| OpenWrt 定义 | `target/linux/qualcommax/image/ipq50xx.mk` → `xiaomi_redmi-ax5400` |

> Redmi AX6000 是 MT7986（mediatek-filogic），AX6S/AX3200 是 MT7622，都不是 ipq50xx，刷错变砖。

## 目录结构

```
.github/workflows/qualcommax_ipq50xx.yml   编译流水线
qualcommax/ipq50xx/xiaomi_redmi-ax5400/
├── diy/diy.sh        接入 PassWall 源 + 移除冲突包
└── passwall.config   追加到官方模板的配置项
build.sh              本地 / WSL2 一键编译
```

新增机型时照这个结构加一层目录、复制一份 workflow 改 `DEVICE_PATH` 即可。

## 自动构建

- 每月 1 日、16 日 08:00 CST 自动构建
- 推送修改到 `main`（仅当 `.github/workflows/**` 或 `qualcommax/**` 变动）触发
- Actions 页手动运行 **Build X-WRT for Redmi AX5400**，可选：
  - `ssh`：开 SSH 进 runner 调试
  - `keep_cores`：`both` / `xray` / `singbox`，只留一个内核能省编译时间和体积
- 编译完成后发布到 Releases，tag 为 `x-wrt-ax5400_<日期>`，只保留最近 2 个

首次使用前确认仓库 **Settings → Actions → General** 已允许运行工作流并开放读写权限（用于上传 Release）。

产物：

```
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-initramfs-factory.ubi   过渡镜像
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-factory.ubi
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-sysupgrade.bin 正式固件
```

编译耗时约 1.5–3 小时（Xray/SingBox 是 Go 写的，会先编一整套 host golang）。

## 本地编译

```bash
./build.sh                  # 全量编译
./build.sh menuconfig       # 先自己勾包再编译
XWRT_BRANCH=master JOBS=8 ./build.sh
```

要求：Ubuntu 22.04/24.04、Debian 12 或 WSL2；**必须在 ext4 原生目录**（`~/`），不能在 `/mnt/c`；预留 40GB 磁盘。

## PassWall 接入要点

1. **仓库地址已迁移**：`xiaorouji/openwrt-passwall` 已 404，现址为
   `Openwrt-Passwall/openwrt-passwall` + `Openwrt-Passwall/openwrt-passwall-packages`（main 分支）
2. **冲突处理**：x-wrt packages feed 自带 `xray-core`、`sing-box`、`v2ray-geodata`，与 passwall-packages 同名，必须先删（已在 `diy.sh` 里做）。`chinadns-ng`、`geoview` 官方 feed 没有，只能由 passwall-packages 提供
3. **透明代理选 nftables**：x-wrt 用 firewall4，选 iptables 的话规则不生效
4. **省时间**：官方模板默认 `CONFIG_TARGET_MULTI_PROFILE=y` 会编十几台设备，workflow 里已关掉并改成只编 AX5400

## 刷机

1. **开 SSH**：[XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)（`run.bat`，不要管理员运行）。原厂固件需 ≤ 1.0.63，高于此版本先降级
2. **备份**：菜单选 4，备份全部分区（存到 `xmir-patcher/backups/`）
3. **过渡镜像**：刷 `initramfs-factory.ubi`
   （也可 SSH 后 `ubiformat /dev/mtd19 -y -f /tmp/xxx-initramfs-factory.ubi` + `nvram set flag_boot_rootfs=1` + `nvram commit`）
4. **固化**：`sysupgrade -n -v /tmp/xxx-squashfs-sysupgrade.bin`

> 这台机器用的是 UBI unified rootfs，**必须走 initramfs 过渡**，不能直接刷 sysupgrade。

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| feeds 找不到 passwall | 地址写成了已失效的 `xiaorouji/*` |
| xray-core / sing-box 版本冲突 | 没删官方 feed 里的同名包，见 `diy.sh` |
| 编译超时 | 已关 MULTI_PROFILE 只编一台；仍超时就把 `keep_cores` 设成单个 |
| golang 编译失败 | 内存或磁盘不足，减 JOBS 或换更大机器 |
| 刷完无线不工作 | 型号不对应，核对 RA74 |
| PassWall 无分流规则 | 缺 geoview（SingBox 25.3.9+ 强依赖）或 geodata |

## 致谢

[X-WRT](https://github.com/x-wrt/x-wrt) · [PassWall](https://github.com/Openwrt-Passwall/openwrt-passwall) · [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
