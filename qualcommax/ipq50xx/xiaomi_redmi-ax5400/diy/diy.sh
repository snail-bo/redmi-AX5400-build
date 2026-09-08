#!/bin/bash
# 在 openwrt/ 源码根目录执行（由 workflow 在 feeds install 前调用）
# 作用：接入 PassWall 源，并移除与 passwall-packages 重名的官方包
set -e

# 1. 固定 X-WRT 官方 feeds，避免同一源码提交在不同时间解析出不同依赖。
pin_feed() {
  name="$1"
  revision="$2"
  sed -i -E "/^src-git(-full)? ${name} / s#([;^][^ ]*)?\$#^${revision}#" feeds.conf.default
  grep -q -E "^src-git(-full)? ${name} .+\^${revision}$" feeds.conf.default || {
    echo "无法固定 feed: $name" >&2
    exit 1
  }
}

pin_feed packages 8673421bbd18b46e40508ee0bddc2af0745fd3b9
pin_feed luci e6c1f2c6c73ba506787f6ed4c3fac459ffe624cc
pin_feed routing 4b9891b9136259f93294a424507ed24c5e8c1cbd
pin_feed telephony 5d68d53c160a325ea9d03fce393e051573bcc736
pin_feed video 644a66261288b4a95dbc6e46fe805d33cb9f71d9
pin_feed x 8591f0870f28e7d73313b3ad0022ebb02fda826d

# 2. 追加并固定 PassWall 源
# 注意：xiaorouji/openwrt-passwall 已 404，官方现址为 Openwrt-Passwall 组织
grep -q '^src-git passwall_packages ' feeds.conf.default || \
  echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^1cda8ce772ba2854e129cd0299efd57975d64492' >> feeds.conf.default
grep -q '^src-git passwall_luci ' feeds.conf.default || \
  echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git^0db5c7b2865e45494cbb8457c35da6af602c9aa8' >> feeds.conf.default

# 3. 移除与 passwall-packages 重名的官方包，避免版本冲突
# （chinadns-ng、geoview 官方 feed 里没有，必须由 passwall-packages 提供）
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/luci/applications/luci-app-passwall

echo "==> diy.sh done: PassWall feeds ready"
