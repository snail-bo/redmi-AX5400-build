#!/bin/bash
set -euo pipefail

pin_feed() {
  local name="$1"
  local revision="$2"
  sed -i -E "/^src-git(-full)? ${name} / s#([;^][^ ]*)?\$#^${revision}#" feeds.conf.default
  grep -q -E "^src-git(-full)? ${name} .+\^${revision}$" feeds.conf.default || {
    echo "Unable to pin feed: $name" >&2
    exit 1
  }
}

# Official feeds from the same May 2026 snapshot period. LuCI is the exact
# revision reported by the known-working router.
pin_feed packages f10dfca2ba531f33685cbed2dec36e901a3c1fd1
pin_feed luci c707d21a010ae958d655f37aa8895571a85d6605
pin_feed routing 776e7160636a7f1add27483ac926dadeb248bb65
pin_feed telephony 4d8d33a023b24c52cd9443b9dc201fbdfe9c6aef
pin_feed video 393e8eac5b45c5a1dc455ffe0e19e7651ad508a3

passwall_packages='https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^74f1ae3cecaa2346a96ce5c311232fad6e94e48d'
passwall_luci='https://github.com/Openwrt-Passwall/openwrt-passwall.git^b09a1abc9f3e365c200a479bd25fc9077455fff9'

sed -i -E '/^src-git(-full)? passwall_(packages|luci) /d' feeds.conf.default
{
  echo "src-git passwall_packages $passwall_packages"
  echo "src-git passwall_luci $passwall_luci"
  cat feeds.conf.default
} > feeds.conf.default.new
mv feeds.conf.default.new feeds.conf.default

head -n 2 feeds.conf.default | grep -q '^src-git passwall_' || {
  echo "PassWall feeds are not first in feeds.conf.default" >&2
  exit 1
}

echo "==> OpenWrt and all feeds pinned to the working snapshot period"
