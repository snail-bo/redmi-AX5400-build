#!/bin/bash
# 在 openwrt/ 源码根目录执行（由 workflow 在 feeds install 前调用）
# 作用：接入 PassWall 源，并移除与 passwall-packages 重名的官方包
set -e

# 1. 追加 PassWall 源
# 注意：xiaorouji/openwrt-passwall 已 404，官方现址为 Openwrt-Passwall 组织
if ! grep -q 'passwall_packages' feeds.conf.default; then
  cat >> feeds.conf.default <<'EOF'
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main
EOF
fi

# 2. 移除与 passwall-packages 重名的官方包，避免版本冲突
# （chinadns-ng、geoview 官方 feed 里没有，必须由 passwall-packages 提供）
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/luci/applications/luci-app-passwall

echo "==> diy.sh done: PassWall feeds ready"
