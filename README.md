# X-WRT + PassWall 自动编译 Xiaomi Redmi AX5400（qualcommax/ipq50xx）

## 0. 先确认你手里是哪台机器

| 项目 | 值 |
|---|---|
| 型号代码 | **RA74**（机身标签上核对） |
| SoC | Qualcomm IPQ5018 双核 Cortex-A53 @1.0GHz |
| 内存 | 512 MiB DDR3L |
| 闪存 | 128 MiB NAND（Gigadevice） |
| 无线 | IPQ5018 2.4G(2x2) + QCN9024 5G(4x4) |
| OpenWrt 位置 | `target/linux/qualcommax/image/ipq50xx.mk` → `xiaomi_redmi-ax5400` |

> 注意区分：Redmi AX6000 是 MT7986（mediatek-filogic），Redmi AX6S/AX3200 是 MT7622，**都不是 ipq50xx**。刷错直接变砖。

X-WRT 官方其实**已经在编这个机型**（`x-wrt-26.04-b202609050853-qualcommax-ipq50xx-xiaomi_redmi-ax5400-*.bin`，约 21-22MB），只是官方固件不带 PassWall。所以有两条路：

- 想省事 → 第 4 节「官方固件 + 自己编 ipk」
- 想要一份集成 PassWall、可复现、改完自动出包的固件 → 第 1/2 节

---

## 1. 方案 A：GitHub Actions 自动编译（推荐）

X-WRT 官方自己的发布流水线就是这套逻辑（仓库 `x-wrt/build-release`：`main.yml` → `build.sh` → `feeds/x/rom/lede/make.sh`）。我们要做的是把它精简成"只编 IPQ50xx 一个机型 + 加 PassWall"。

### 步骤

1. 本目录已经初始化为 git 仓库（main 分支）。推到你自己的 GitHub：

   ```bash
   gh auth login                                            # 首次需要先登录
   gh repo create my-xwrt-ax5400 --public --source=. --push # 建仓库并推送
   ```

   或手动在 GitHub 建空仓库后：

   ```bash
   git remote add origin git@github.com:<你的账号>/my-xwrt-ax5400.git
   git push -u origin main
   ```

   目录内容：

   ```
   .github/workflows/build-ax5400.yml   编译流水线
   .gitattributes                       强制 LF
   .gitignore                           忽略 out/ 与源码目录
   passwall.config                      PassWall 配置片段
   build.sh                             本地一键编译
   README.md
   ```

2. Actions 页面 → **Build X-WRT Redmi AX5400 + PassWall** → **Run workflow**
   - `xwrt_branch`：默认 `master`（想要固定版本就填 tag/分支名）
   - `keep_cores`：`both` / `xray` / `singbox`（只留一个内核能省不少编译时间和体积）
   - `upload_release`：勾上会把产物打包发布到 GitHub Release（tag 为 `ax5400-<run_number>`），不勾就只放在 Artifacts

3. 等约 **1.5–3 小时**（IPQ50xx 单设备 + host golang 编译），在 Artifacts 里下载 `x-wrt-ax5400-passwall`，里面有：

   ```
   x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-initramfs-factory.ubi   ← 过渡镜像
   x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-factory.ubi
   x-wrt-<ver>-qualcommax-ipq50xx-xiaomi_redmi-ax5400-squashfs-sysupgrade.bin ← 正式固件
   ```

4. 想做**定时自动编译**：把 yml 里 `schedule` 那段注释打开即可（示例是每周五 UTC 08:00，即北京时间周五 16:00）。

### 关键实现点（照抄官方做法）

- 配置模板直接用官方的：`feeds/x/rom/lede/config.qualcommax-ipq50xx`（来自 `x-wrt/com.x-wrt` 这个 x feed）
- 官方模板默认 `CONFIG_TARGET_MULTI_PROFILE=y`，会把 ipq50xx 的十几台设备全编一遍。脚本里把它关掉、改成单设备 `CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_redmi-ax5400=y`，能把编译时间砍掉一多半。

---

## 2. 方案 B：本地一键脚本（WSL2 / Ubuntu）

```bash
git clone https://github.com/x-wrt/x-wrt.git   # 或直接把本目录拷进 WSL
cd x-wrt-ax5400-passwall
chmod +x build.sh
./build.sh                 # 直接编
./build.sh menuconfig      # 先自己勾包再编
```

硬性要求：

- 必须用 **WSL2 的 ext4 原生目录**（`~/`），**不能在 `/mnt/c`** 下编译，符号链接和大小写敏感会直接失败
- 首次编译预留 **40GB 磁盘** 和 2 小时以上；二次编译有 ccache 会快很多
- 内存建议 ≥8GB，JOBS 默认等于 CPU 核数

---

## 3. PassWall 接入的坑（这一段最重要）

### 3.1 仓库地址变了

`xiaorouji/openwrt-passwall` 已 404，官方迁移到：

```
https://github.com/Openwrt-Passwall/openwrt-passwall           (luci 界面)
https://github.com/Openwrt-Passwall/openwrt-passwall-packages   (xray/sing-box/chinadns-ng 等)
```

feeds 写法（追加到 `feeds.conf.default` 末尾）：

```
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
```

### 3.2 必须处理包冲突

x-wrt 的 packages feed 自带 `xray-core`、`sing-box`、`v2ray-geodata`，与 passwall-packages 同名会冲突。安装 feeds 后先删：

```bash
rm -rf feeds/packages/net/xray-core feeds/packages/net/sing-box feeds/packages/net/v2ray-geodata
rm -rf feeds/luci/applications/luci-app-passwall
./scripts/feeds install -a -p passwall_packages
./scripts/feeds install -a -p passwall_luci
```

`chinadns-ng`、`geoview` x-wrt 官方 feed 里没有，只能由 passwall-packages 提供，所以这个 feed 不能省。

### 3.3 透明代理要选 nftables

x-wrt 用 firewall4（nftables），所以 `Iptables_Transparent_Proxy` 必须关、`Nftables_Transparent_Proxy` 必须开，否则 PassWall 起来后规则不生效。

### 3.4 体积与时间

- Xray / SingBox 是 Go 写的，会**先编译一整套 host golang**，这是整个流程最耗时的一步（30 分钟起）
- `INCLUDE_*` 默认在 aarch64 上会开一堆（Haproxy、Simple-Obfs、SS-Rust、V2ray-Plugin…）。本仓库的 `passwall.config` 已全部关掉，只留 Xray + SingBox + Geodata + Geoview
- 极限省时：`keep_cores` 只选一个，PassWall 照样能用

---

## 4. 方案 C（更省事）：官方固件 + 自己编 ipk

不想等完整编译的话：

1. 下载官方固件：https://downloads.x-wrt.com/rom/ 搜 `redmi-ax5400`
2. 在同页 `sdk/` 目录下载 `qualcommax-ipq50xx` 的 SDK
3. 用 SDK 单独编 `luci-app-passwall` + 内核 + geodata 这几个 ipk（十几分钟）
4. `opkg install *.ipk`

缺点：SDK 编出来的 ipk 依赖内核版本号严格匹配，x-wrt 一升级就得重编；优点：快。

---

## 5. 刷机流程（Redmi AX5400）

1. **开 SSH**：用 [XMiR Patcher](https://github.com/openwrt-xiaomi/xmir-patcher)（`run.bat`，**不要管理员运行**）。原厂固件需 ≤ 1.0.63，高于此版本先降级
2. **备份**：XMiR Patcher 菜单选 4，备份全部分区（文件在 `xmir-patcher/backups/`）
3. **刷过渡镜像**：选 XMiR Patcher 的刷机项，载入 `...-initramfs-factory.ubi`
   （或 SSH 进路由用 `ubiformat /dev/mtd19 -y -f /tmp/xxx-initramfs-factory.ubi` + `nvram set flag_boot_rootfs=1` + `nvram commit`）
4. **固化**：临时系统起来后 `sysupgrade -n -v /tmp/xxx-squashfs-sysupgrade.bin`
5. 后续升级直接用 sysupgrade 即可

> 因为 OpenWrt 对这台机器用的是 UBI unified rootfs，**必须走 initramfs 过渡**，不能直接刷 sysupgrade。

---

## 6. 文件说明

| 文件 | 作用 |
|---|---|
| `.github/workflows/build-ax5400.yml` | GitHub Actions 全自动编译 + 上传产物 + 可选 Release |
| `passwall.config` | 追加到官方 ipq50xx 模板上的 PassWall 配置项 |
| `build.sh` | 本地 / WSL2 一键编译脚本 |
| `.gitattributes` | 强制 LF，避免 Windows 检出后 shell 脚本被 `\r` 搞坏 |
| `out/` | 编译产物输出目录（脚本自动创建，已 gitignore） |

---

## 7. 常见报错

| 现象 | 原因 / 处理 |
|---|---|
| `feeds` 里找不到 passwall | 仓库地址写成了已失效的 `xiaorouji/*`，改成 `Openwrt-Passwall/*` |
| `xray-core` / `sing-box` 报版本冲突 | 没删官方 feed 里的同名包，见 3.2 |
| 编译 6 小时超时 | 关掉 `MULTI_PROFILE` 只编一台；只留一个 core；开启 ccache |
| golang 编译失败 | 内存不足或磁盘不够，减 `JOBS`、换 8C/16G 机器或只留一个 core |
| 刷完无线不工作 | 型号不对应（AX6000/AX6S 固件刷进了 AX5400），核对 RA74 |
| PassWall 页面报错无规则 | 没装 geoview（SingBox 25.3.9+ 强制依赖）或 geodata 缺失 |
