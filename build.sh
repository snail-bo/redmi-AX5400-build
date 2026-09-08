#!/bin/bash
# ---------------------------------------------------------------
# X-WRT (qualcommax/ipq50xx) Xiaomi Redmi AX5400 + PassWall 一键编译
# 环境：Ubuntu 22.04/24.04、Debian 12、WSL2（不要在 /mnt/c 下编译，务必放在 ext4 原生目录）
# 用法：
#   ./build.sh                 # 全量编译
#   ./build.sh menuconfig      # 先弹出菜单自己选包，再编译
#   XWRT_BRANCH=master JOBS=8 ./build.sh
# ---------------------------------------------------------------
set -e

XWRT_BRANCH=${XWRT_BRANCH:-master}
JOBS=${JOBS:-$(nproc)}
WORK=${WORK:-$HOME/x-wrt-build}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "==> 目标：qualcommax/ipq50xx  xiaomi_redmi-ax5400"
echo "==> 源码分支：$XWRT_BRANCH   工作目录：$WORK   并行：$JOBS"

# ---------- 1. 依赖 ----------
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
  gettext git libncurses-dev libssl-dev python3 python3-setuptools rsync \
  swig unzip zlib1g-dev file wget curl ccache libelf-dev

export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache -M 20G

# ---------- 2. 源码 ----------
mkdir -p "$WORK"
if [ ! -d "$WORK/x-wrt" ]; then
  git clone --depth 1 -b "$XWRT_BRANCH" https://github.com/x-wrt/x-wrt.git "$WORK/x-wrt"
fi
cd "$WORK/x-wrt"

# ---------- 3. PassWall 源 ----------
if ! grep -q passwall_packages feeds.conf.default; then
  cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
EOF
fi

# ---------- 4. feeds ----------
./scripts/feeds update -a
./scripts/feeds install -a
# 移除与 passwall-packages 重名的包，避免版本冲突
rm -rf feeds/packages/net/xray-core feeds/packages/net/sing-box feeds/packages/net/v2ray-geodata
rm -rf feeds/luci/applications/luci-app-passwall
./scripts/feeds update -a
./scripts/feeds install -a -p passwall_packages
./scripts/feeds install -a -p passwall_luci

# ---------- 5. .config ----------
cp feeds/x/rom/lede/config.qualcommax-ipq50xx .config
# 只编 AX5400 一台设备
sed -i 's/^CONFIG_TARGET_MULTI_PROFILE=y/# CONFIG_TARGET_MULTI_PROFILE is not set/' .config
sed -i 's/^CONFIG_TARGET_PER_DEVICE_ROOTFS=y/# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set/' .config
echo 'CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_redmi-ax5400=y' >> .config
cat "$SCRIPT_DIR/passwall.config" >> .config
echo 'CONFIG_CCACHE=y' >> .config
make defconfig

if [ "$1" = "menuconfig" ]; then
  make menuconfig
  ./scripts/diffconfig.sh > "$SCRIPT_DIR/config.seed"
fi

# ---------- 6. 下载 & 编译 ----------
make download -j8
make -j"$JOBS" || make -j1 V=s

# ---------- 7. 产物 ----------
mkdir -p "$SCRIPT_DIR/out"
find bin/targets -type f -name '*redmi-ax5400*' -exec cp {} "$SCRIPT_DIR/out/" \;
cp .config "$SCRIPT_DIR/out/config.build"
ls -lh "$SCRIPT_DIR/out"
echo "==> 完成：$SCRIPT_DIR/out"
