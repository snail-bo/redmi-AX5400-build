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
├── diy/diy.sh        改浅克隆 + 固定 feeds + 接入 PassWall 源（置顶保证同名包优先）
├── passwall.config   追加到官方模板的 PassWall 配置项
└── wireless.config   无线包显式置 =y（关 MULTI_PROFILE 后的必要补偿）
build.sh              本地 / WSL2 一键编译
```

新增机型时照这个结构加一层目录、复制一份 workflow 改 `DEVICE_PATH` 即可。

## 自动构建

- 每月 1 日、16 日 08:00 CST 自动构建
- 推送修改到 `main`（仅当 `.github/workflows/**` 或 `qualcommax/**` 变动）触发
- Actions 页手动运行 **Build X-WRT for Redmi AX5400**，可选：
  - `ssh`：开 SSH 进 runner 调试
  - `keep_cores`：默认 `singbox`，也可选 `xray` / `both`
- 编译完成后发布到 Releases，tag 为 `x-wrt-ax5400_<日期>_<运行序号>`，只保留最近 2 个
- X-WRT、官方 feeds 与 PassWall 均固定到明确提交；升级时需在 workflow、`build.sh` 和 `diy.sh` 中显式更新提交号
- Release 同时包含 `source-versions.txt`、`config.build` 和 SHA-256 校验文件，便于追踪构建来源

首次使用前确认仓库 **Settings → Actions → General** 已允许运行工作流并开放读写权限（用于上传 Release）。

产物：

```
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-initramfs-factory.ubi   过渡镜像
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-factory.ubi
x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-sysupgrade.bin 正式固件
```

默认只编译 SingBox；编译耗时约 1.5–3 小时（代理核心是 Go 编写，会先编译 host golang）。

## 本地编译

```bash
./build.sh                  # 全量编译
./build.sh menuconfig       # 先自己勾包再编译
XWRT_REF=<commit-or-tag> JOBS=8 ./build.sh
KEEP_CORES=xray ./build.sh  # 改为只保留 Xray；也可设为 both
```

要求：Ubuntu 22.04/24.04、Debian 12 或 WSL2；**必须在 ext4 原生目录**（`~/`），不能在 `/mnt/c`；预留 40GB 磁盘。

脚本默认使用与 Actions 相同的固定 X-WRT 提交。已有源码目录会先 fetch 并切换到指定提交；如果目录中存在会被覆盖的未提交修改，Git 会拒绝切换并让脚本安全退出。

## PassWall 接入要点

1. **仓库地址已迁移**：`xiaorouji/openwrt-passwall` 已 404，现址为
   `Openwrt-Passwall/openwrt-passwall` + `Openwrt-Passwall/openwrt-passwall-packages`（main 分支）
2. **同名包靠"排在最前面"抢占，不靠删文件**：x-wrt packages feed 自带 `xray-core`、`sing-box`、`v2ray-geodata` 和 passwall-packages 同名。`scripts/feeds` 的 install 是先到先得——`lookup_src()` 按 `feeds.conf.default` 顺序取第一个含该包的 feed，随后用全局 `%installed` 标记，后面的同名包一律跳过。所以 `diy.sh` 把两个 PassWall 源插到文件**开头**。`chinadns-ng`、`geoview` 官方 feed 没有，只能由 passwall-packages 提供
   - 不要用 `rm -rf feeds/packages/net/xray-core` 来解决：目录删了，`feeds/packages.index` 里的条目还在，install 只会建出一个悬空符号链接，问题更隐蔽
3. **透明代理选 nftables**：x-wrt 用 firewall4，选 iptables 的话规则不生效
4. **省时间**：官方模板默认 `CONFIG_TARGET_MULTI_PROFILE=y` 会编十几台设备，workflow 里已关掉并改成只编 AX5400
   - **副作用要注意**：关掉后 `CONFIG_TARGET_DEVICE_PACKAGES_..._xiaomi_redmi-ax5400` 这条逐设备包列表会失效，官方模板里那些 `=m` 的包（含全部无线驱动、固件、wpad）就只产 ipk、不打进镜像，**刷完没有 WiFi**。已在 `wireless.config` 里把必需项显式改成 `=y` 补偿，并在 `defconfig` 后和打包前各做一次校验
   - 不要为了"还原官方包集合"改回 `MULTI_PROFILE=y`：那条列表含 openvpn / nginx / uwsgi / wireguard 等几十个包，编译时间会显著变长
5. **来源校验**：安装 feeds 后会检查 PassWall、Xray、SingBox 和 geodata 的符号链接来源；上游目录变化或同名包冲突会直接终止构建
6. **必须浅克隆**：X-WRT 默认用 `src-git-full`，会 `git clone` 每个 feed 的**完整历史**，8 个 feed 合计数 GB。在 GitHub-hosted runner 上会慢到让 feeds 步骤挂死、最终 runner 心跳失联（`The hosted runner lost communication with the server`）。`diy.sh` 已把所有 `src-git-full` 改成 `src-git`，其 `init_commit` 模板为 `git clone --depth 1` + `git fetch --depth=1 origin <commit>`，与我们固定的提交完全兼容

## 版本升级

为了让发布的固件可复现、可审计，流水线不自动追踪上游分支。升级时：

1. 更新 `.github/workflows/qualcommax_ipq50xx.yml` 和 `build.sh` 中的 `XWRT_REF`
2. 更新 `diy.sh` 中 X-WRT 官方 feeds 和两个 PassWall feed 的提交号
3. 手动运行一次 Actions，确认配置、编译及两个必需镜像的校验全部通过
4. 检查 Release 内的 `source-versions.txt` 与预期提交一致

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
| `xray-core 未从 passwall_packages 安装` | PassWall 源没排在 `feeds.conf.default` 开头，同名包被官方 feed 抢走 |
| 刷完没有 WiFi | 关了 MULTI_PROFILE 导致逐设备包列表失效，无线包停在 `=m`。见 `wireless.config`；已在设备上可先用 opkg 救急 |
| 无线接口起不来 | 缺 `ipq-wifi-xiaomi_redmi-ax5400`（板级校准数据 BDF）或 ath11k 固件 |
| `xx 是悬空符号链接` | 用 `rm -rf` 删过官方 feed 目录但没重建 index，改成置顶即可 |
| 编译超时 | 已关 MULTI_PROFILE 只编一台；仍超时就把 `keep_cores` 设成单个 |
| golang 编译失败 | 内存或磁盘不足，减 JOBS 或换更大机器 |
| 刷完无线不工作 | 型号不对应，核对 RA74 |
| PassWall 无分流规则 | 缺 geoview（SingBox 25.3.9+ 强依赖）或 geodata |

## 致谢

[X-WRT](https://github.com/x-wrt/x-wrt) · [PassWall](https://github.com/Openwrt-Passwall/openwrt-passwall) · [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
