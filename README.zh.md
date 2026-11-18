![GitHub License](https://img.shields.io/github/license/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikkinikki-org/OpenWrt-momo/total?style=for-the-badge&logo=github) ![GitHub Repo stars](https://img.shields.io/github/stars/nikkinikki-org/OpenWrt-momo?style=for-the-badge&logo=github) [![Telegram](https://img.shields.io/badge/Telegram-gray?style=for-the-badge&logo=telegram)](https://t.me/nikkinikki_org)

中文 | [English](README.md)

# Momo

在 OpenWrt 上使用 sing-box 进行透明代理。

## 环境要求

- OpenWrt >= 24.10
- Linux Kernel >= 5.13
- firewall4

## 功能

- 透明代理 (Redirect/TPROXY/TUN, IPv4 和/或 IPv6)
- 访问控制
- 配置文件编辑器
- 定时重启

本 fork 在内存中生成运行配置。开启配置测试时，先通过 sing-box 检查，再替换运行文件。订阅刷新会先检查 JSON 格式，保留旧文件以应对空配置和网页错误。订阅或运行配置内容相同时会保留原文件。

选择优先远程订阅且已有缓存时，服务启动等待远程请求最多 10 秒。请求失败时使用本地订阅。需要从单独地址获取流量信息时，可在 LuCI 手动刷新。

同一订阅同时收到刷新请求时只执行一次下载校验。重载和重启会先准备配置，通过后再切换服务。LuCI 只刷新当前日志标签的最后 16 KiB，也可按需下载完整日志。配置编辑器跳过内容相同的写入。

本 fork 的 ARM64 测试包见 [GitHub Actions](https://github.com/joeyijun/OpenWrt-momo/actions/workflows/check-packages.yml)。请选择匹配系统版本的构建，momo 和 LuCI 使用同一构建中的软件包。

## 安装或更新上游版本

下列命令安装上游软件包。本 fork 的软件包可使用下文的编译步骤生成。

### A. 从软件源安装（推荐）

1. 添加源

```shell
# 只需运行一次
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/feed.sh | ash
```

2. 安装

```shell
# 你可以从 shell 执行命令安装或者从 LuCI 的`软件包`菜单安装
# for opkg
opkg install momo
opkg install luci-app-momo
opkg install luci-i18n-momo-zh-cn
# for apk
apk add momo
apk add luci-app-momo
apk add luci-i18n-momo-zh-cn
```

### B. 从发行版安装

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/install.sh | ash
```

## 卸载并重置

```shell
wget -O - https://github.com/nikkinikki-org/OpenWrt-momo/raw/refs/heads/main/uninstall.sh | ash
```

## 如何使用

查看 [Wiki](https://github.com/nikkinikki-org/OpenWrt-momo/wiki)

## 如何工作

1. 启动 sing-box。
2. 设置定时重启。
3. 从配置文件读取必要的参数。
4. 配置 IP 规则/路由。
5. 生成防火墙配置并应用。

注意上述步骤可能因配置而变动。

## 编译

```shell
# 添加源
echo "src-git momo https://github.com/joeyijun/OpenWrt-momo.git;main" >> "feeds.conf.default"
# 更新并安装源
./scripts/feeds update -a
./scripts/feeds install -a
# 编译
make package/luci-app-momo/compile
```

编译结果可以在`bin/packages/your_architecture/momo`内找到。

## 依赖

- ca-bundle
- curl
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- sing-box >= 1.12

## 贡献者

[![贡献者](https://contrib.rocks/image?repo=nikkinikki-org/OpenWrt-momo)](https://github.com/nikkinikki-org/OpenWrt-momo/graphs/contributors)
