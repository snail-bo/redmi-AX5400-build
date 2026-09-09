#!/bin/bash
# 在 openwrt/ 源码根目录执行（由 workflow 在 feeds install 前调用）
# 作用：接入 PassWall 源，并移除与 passwall-packages 重名的官方包
set -e

# 0. 全量克隆改浅克隆
# X-WRT 默认用 src-git-full，其 init_commit 模板是 `git clone <url>` —— 拉完整历史。
# 8 个 feed 合计数 GB，在 Actions runner 上既慢又吃内存与磁盘，实测会让
# feeds 步骤挂到 runner 心跳失联。
# src-git 的 init_commit 模板是：
#   git clone --depth 1 <url> <dir> \
#     && git fetch --depth=1 origin <commit> && git checkout <commit>
# 只取一个提交快照，且与下面 pin 的 commit 完全兼容。
sed -i -E 's/^src-git-full /src-git /' feeds.conf.default

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

# 2. 接入并固定 PassWall 源
# 注意：xiaorouji/openwrt-passwall 已 404，官方现址为 Openwrt-Passwall 组织
#
# 【关键】必须插到 feeds.conf.default 的最前面，而不是追加到末尾。
# scripts/feeds 的 install 是"先到先得"：
#   * lookup_src() 按 feeds.conf 的顺序返回第一个含该包的 feed；
#   * install_src() 用全局 %installed 记录已装源包，同名包后续一律跳过；
#   * do_install_src() 的符号链接建在"胜出的那个 feed"目录下。
# x-wrt/packages 自带 xray-core / sing-box / v2ray-geodata，若 PassWall 源排在后面，
# 这三个包会被官方 feed 抢占，package/feeds/passwall_packages/ 下永远不会有它们。
#
# 同理，不要再靠 `rm -rf feeds/packages/net/xray-core` 解决冲突：
# 目录删了，feeds/packages.index 里的条目还在，install 只会建出一个悬空符号链接。
PASSWALL_PACKAGES_URL='https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^1cda8ce772ba2854e129cd0299efd57975d64492'
PASSWALL_LUCI_URL='https://github.com/Openwrt-Passwall/openwrt-passwall.git^0db5c7b2865e45494cbb8457c35da6af602c9aa8'

if ! grep -q -E '^src-git(-full)? passwall_packages ' feeds.conf.default ||
   ! grep -q -E '^src-git(-full)? passwall_luci ' feeds.conf.default; then
  {
    echo "src-git passwall_packages $PASSWALL_PACKAGES_URL"
    echo "src-git passwall_luci $PASSWALL_LUCI_URL"
    cat feeds.conf.default
  } > feeds.conf.default.new
  mv feeds.conf.default.new feeds.conf.default
fi

# 校验：PassWall 两个源必须在文件开头（决定同名包的归属）
head -n 2 feeds.conf.default | grep -q '^src-git passwall_' || {
  echo "PassWall feeds 未排在 feeds.conf.default 开头" >&2
  exit 1
}

echo "==> diy.sh done: PassWall feeds ready（已置顶，优先于官方 feeds）"
