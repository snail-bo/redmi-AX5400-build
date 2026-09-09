#!/bin/bash
# ---------------------------------------------------------------
# X-WRT (qualcommax/ipq50xx) Xiaomi Redmi AX5400 + PassWall 一键编译
# 环境：Ubuntu 22.04/24.04、Debian 12、WSL2（不要在 /mnt/c 下编译，务必放在 ext4 原生目录）
# 用法：
#   ./build.sh                 # 全量编译
#   ./build.sh menuconfig      # 先弹出菜单自己选包，再编译
#   XWRT_REF=<commit-or-tag> JOBS=8 ./build.sh
# ---------------------------------------------------------------
set -euo pipefail

XWRT_REF=${XWRT_REF:-1e5118167060b432564801453d5a8eb63015962e}
JOBS=${JOBS:-$(nproc)}
WORK=${WORK:-$HOME/x-wrt-build}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DEVICE_DIR="$SCRIPT_DIR/qualcommax/ipq50xx/xiaomi_redmi-ax5400"

echo "==> 目标：qualcommax/ipq50xx  xiaomi_redmi-ax5400"
echo "==> 源码版本：$XWRT_REF   工作目录：$WORK   并行：$JOBS"

# ---------- 1. 依赖 ----------
sudo apt-get update
mapfile -t packages < "$SCRIPT_DIR/.github/openwrt-build-packages.txt"
sudo apt-get install -y --no-install-recommends "${packages[@]}"

export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 20G

# ---------- 2. 源码 ----------
mkdir -p "$WORK"
if [ ! -d "$WORK/x-wrt/.git" ]; then
  git init "$WORK/x-wrt"
  git -C "$WORK/x-wrt" remote add origin https://github.com/x-wrt/x-wrt.git
fi
git -C "$WORK/x-wrt" fetch --depth=1 origin "$XWRT_REF"
# 如有未提交修改，checkout 会拒绝覆盖并安全退出。
git -C "$WORK/x-wrt" checkout --detach FETCH_HEAD
cd "$WORK/x-wrt"

# ---------- 3. feeds（PassWall 源与冲突包处理都在 diy.sh 里）----------
./scripts/feeds update -a
"$DEVICE_DIR/diy/diy.sh"
# 只拉取 diy.sh 刚置顶的 PassWall feeds（官方 feeds 上一步已 update 完）
./scripts/feeds update passwall_packages passwall_luci
./scripts/feeds install -a
# 校验：PassWall 相关包必须真正落在 passwall_* 目录下，且没有悬空链接
luci_link="package/feeds/passwall_luci/luci-app-passwall"
test -L "$luci_link" || { echo "luci-app-passwall 未从 passwall_luci 安装" >&2; exit 1; }
test "$(readlink "$luci_link")" = "../../../feeds/passwall_luci/luci-app-passwall"
test -e "$luci_link" || { echo "luci-app-passwall 是悬空符号链接" >&2; exit 1; }
for package in xray-core sing-box v2ray-geodata chinadns-ng geoview; do
  target="package/feeds/passwall_packages/$package"
  test -L "$target" || { echo "$package 未从 passwall_packages 安装" >&2; exit 1; }
  test -e "$target" || { echo "$package 是悬空符号链接" >&2; exit 1; }
  test ! -e "package/feeds/packages/$package" || {
    echo "$package 被官方 packages feed 抢占" >&2; ls -l "package/feeds/packages/$package" >&2; exit 1; }
done

# ---------- 5. .config ----------
cp feeds/x/rom/lede/config.qualcommax-ipq50xx .config
# 只编 AX5400 一台设备
sed -i 's/^CONFIG_TARGET_MULTI_PROFILE=y/# CONFIG_TARGET_MULTI_PROFILE is not set/' .config
sed -i 's/^CONFIG_TARGET_PER_DEVICE_ROOTFS=y/# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set/' .config
echo 'CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_redmi-ax5400=y' >> .config
cat "$DEVICE_DIR/passwall.config" >> .config
# 关掉 MULTI_PROFILE 后官方 per-device 包列表失效，无线包退回 =m（只产 ipk、
# 不打进镜像）。这里显式补回 =y，见 wireless.config。
cat "$DEVICE_DIR/wireless.config" >> .config
echo 'CONFIG_CCACHE=y' >> .config
make defconfig
# 校验：无线相关包必须真的是 =y，否则刷完没有 WiFi
for pkg in kmod-cfg80211 kmod-mac80211 kmod-ath kmod-ath11k kmod-ath11k-ahb \
           kmod-ath11k-pci ath11k-firmware-ipq5018 ath11k-firmware-qcn9074 \
           ipq-wifi-xiaomi_redmi-ax5400 wpad-openssl hostapd-common; do
  grep -qx "CONFIG_PACKAGE_${pkg}=y" .config || {
    echo "$pkg 未内置为 =y，刷机后将没有 WiFi" >&2
    grep -E "^#? ?CONFIG_PACKAGE_${pkg}=" .config >&2
    exit 1
  }
done

if [ "${1:-}" = "menuconfig" ]; then
  make menuconfig
  ./scripts/diffconfig.sh > "$SCRIPT_DIR/config.seed"
fi

# ---------- 6. 下载 & 编译 ----------
make download -j8
make -j"$JOBS" || make -j1 V=s

# ---------- 7. 产物 ----------
mkdir -p "$SCRIPT_DIR/out"
test -n "$(find bin/targets -type f -name '*initramfs-factory.ubi' -print -quit)" || { echo "缺少 initramfs-factory.ubi" >&2; exit 1; }
test -n "$(find bin/targets -type f -name '*squashfs-sysupgrade.bin' -print -quit)" || { echo "缺少 squashfs-sysupgrade.bin" >&2; exit 1; }
find bin/targets -type f -name '*redmi-ax5400*' -exec cp {} "$SCRIPT_DIR/out/" \;
cp .config "$SCRIPT_DIR/out/config.build"
{
  printf 'x-wrt %s\n' "$(git rev-parse HEAD)"
  for feed in feeds/*; do
    test -d "$feed/.git" && printf '%s %s\n' "$(basename "$feed")" "$(git -C "$feed" rev-parse HEAD)"
  done
} > "$SCRIPT_DIR/out/source-versions.txt"
ls -lh "$SCRIPT_DIR/out"
echo "==> 完成：$SCRIPT_DIR/out"
