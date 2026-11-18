![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-momo/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

English | [中文](README.zh.md)

# Momo

Transparent Proxy with sing-box on OpenWrt.

## Prerequisites

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## Feature

- Transparent Proxy (Redirect/TPROXY/TUN, IPv4 and/or IPv6)
- Access Control
- Profile Editor
- Scheduled Restart

This fork generates the runtime profile in memory. When profile testing is enabled, sing-box checks the candidate before it replaces the runtime file. Subscription updates reject malformed and empty configurations. Both operations keep the existing file when its contents match.

When remote subscriptions are preferred and a cached copy exists, startup waits up to 10 seconds for one download attempt and uses the cache if it fails. Manual refreshes also fetch quota details from the optional separate URL.

Concurrent refreshes of the same subscription share a lock. Reload and restart prepare the profile before changing the running service. LuCI polls only the visible log tab and shows up to 16 KiB per refresh, with full logs available on demand. The editor skips writes when the file contents match.

[GitHub Actions](https://github.com/joeyijun/OpenWrt-momo/actions/workflows/check-packages.yml) publishes ARM64 test packages. Choose the build for your OpenWrt version and use the momo and LuCI packages from the same build.

## Install or Update Upstream Packages

These commands install the upstream packages. To build the fork, use the compilation steps below.

### A. Install From Feed (Recommended)

1. Add Feed

```shell
# only needs to be run once
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/feed.sh | ash
```

2. Install

```shell
# you can install from shell or `Software` menu in LuCI
# for opkg
opkg install momo
opkg install luci-app-momo
opkg install luci-i18n-momo-zh-cn
# for apk
apk add momo
apk add luci-app-momo
apk add luci-i18n-momo-zh-cn
```

### B. Install From Release

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/install.sh | ash
```

## Uninstall & Reset

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
```

## How To Use

See [Wiki](https://github.com/nikkinikki-org/OpenWrt-momo/wiki)

## How does it work
 
1. Run sing-box.
2. Set scheduled restart.
3. Get neccesarry param from profile.
4. Set ip rule/route.
5. Generate firewall and apply it.

Note that the steps above may change base on config.

## Compilation

```shell
# add feed
echo "src-git momo https://github.com/joeyijun/OpenWrt-momo.git;main" >> "feeds.conf.default"
# update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# make package
make package/luci-app-momo/compile
```

The package files will be found under `bin/packages/your_architecture/momo`.

## Dependencies

- ca-bundle
- curl
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- sing-box >= 1.12

## Contributors

[![Contributors](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-momo)](https://github.com/nikkinikki-org/OpenWrt-momo/graphs/contributors)
