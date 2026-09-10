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

pin_feed packages bc0a5c06bcfcb7235bb93dbb5aa09e9b0e32b6f0
pin_feed luci 98d8a72ea2f55755c4608ef913867ff1d841889b
pin_feed routing 75994b736e2fa1d259ea4e3a6715893b501aa4ba
pin_feed telephony d3bcb153813b1ff34b3dd0f1bf0dc913984f2921
pin_feed helloworld 4efbf62d431e3ea235be69b8b8f8f537520beb13

passwall_packages='https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^e73ad1c77a96fdaa498807ff7bc717dc92c349ea'
passwall_luci='https://github.com/Openwrt-Passwall/openwrt-passwall.git^c0992fce505b8dcc2331470fe8db97f7d6de9020'

# Put PassWall feeds first so their SingBox and geodata packages win any
# same-name conflict with LEDE's regular feeds.
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

echo "==> LEDE feeds 已固定，PassWall 已置顶"
