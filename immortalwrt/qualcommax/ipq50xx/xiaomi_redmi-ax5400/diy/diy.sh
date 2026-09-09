#!/bin/bash
set -euo pipefail

pin_feed() {
  name="$1"
  revision="$2"
  sed -i -E "/^src-git(-full)? ${name} / s#([;^][^ ]*)?\$#^${revision}#" feeds.conf.default
  grep -q -E "^src-git(-full)? ${name} .+\^${revision}$" feeds.conf.default || {
    echo "无法固定 feed: $name" >&2
    exit 1
  }
}

pin_feed packages 8509f551edb7beb4a6324afca4d84b2bea404b66
pin_feed luci 1df16f1ef5845a9c2cacd5d6f1e0d2fe95cdad37
pin_feed routing 4b9891b9136259f93294a424507ed24c5e8c1cbd
pin_feed telephony 5d68d53c160a325ea9d03fce393e051573bcc736
pin_feed video 644a66261288b4a95dbc6e46fe805d33cb9f71d9

passwall_packages='https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^e73ad1c77a96fdaa498807ff7bc717dc92c349ea'
passwall_luci='https://github.com/Openwrt-Passwall/openwrt-passwall.git^1fa80eab0c289d6547eaeaf4169a17b4eba28acf'

# PassWall 必须排在 packages 前面，同名的 sing-box/geodata 才会选中此源。
# 先移除旧条目，使脚本重复运行或遇到残缺配置时也不会产生重名 feed。
sed -i -E '/^src-git(-full)? passwall_(packages|luci) /d' feeds.conf.default
{
  echo "src-git passwall_packages $passwall_packages"
  echo "src-git passwall_luci $passwall_luci"
  cat feeds.conf.default
} > feeds.conf.default.new
mv feeds.conf.default.new feeds.conf.default

head -n 2 feeds.conf.default | grep -q '^src-git passwall_' || {
  echo "PassWall feeds 未排在 feeds.conf.default 开头" >&2
  exit 1
}

echo "==> ImmortalWrt feeds 已固定，PassWall 已置顶"
