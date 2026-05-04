# 月白历

月白历是一个轻量的 macOS 菜单栏农历日历。它显示公历日期、农历、星期和可选时间；点开后可以查看月历、农历日期、系统节假日订阅，并快速判断某一天距离今天还有多久。

这个项目起因很简单：旧的菜单栏农历工具在新版 macOS 上无法跟随系统菜单栏颜色，于是做了一个更原生、更轻的小替代品。

## 功能

- 菜单栏显示日期、农历、星期，可选时间和秒数
- 点击菜单栏打开月历弹窗
- 右键菜单栏打开设置和退出
- 月历显示公历、农历、系统节假日订阅
- 点击任意日期显示“今天 / N 天前 / N 天后”
- 读取 macOS 系统日历中的节假日订阅，不硬编码节假日
- 只需要日历访问权限

## 权限说明

月白历只申请日历权限，用于读取系统日历中已订阅的节假日日历，例如“中国大陆节假日”。

它不会读取通讯录、定位、提醒事项、网络、辅助功能或其他隐私数据。

详见 [PRIVACY.md](./PRIVACY.md)。

## 系统要求

- macOS 13 或更新版本
- 构建需要 Xcode Command Line Tools，包含 `swiftc`

## 从源码运行

```bash
make run
```

## 构建 App

```bash
make build
```

构建产物：

```text
build/月白历.app
```

## 打包 DMG

```bash
make package
```

打包产物：

```text
dist/月白历-1.0.0.dmg
```

## 重新生成图标

当前图标是代码生成的临时版本，后续可以替换成更正式的设计稿。

```bash
./scripts/regenerate-icon.sh
```

## 本机安装

```bash
make install
```

安装位置：

```text
~/Applications/月白历.app
```

安装脚本会同时写入 LaunchAgent，让月白历登录后自动启动。

## 卸载本机安装

```bash
make uninstall
```

这会停止 LaunchAgent，并移除 `~/Applications/月白历.app`。

## 项目结构

```text
.
├── Sources/Yuebaili/main.swift   # AppKit 主程序
├── Resources/Info.plist          # App 元信息和日历权限说明
├── Resources/AppIcon.icns        # 当前图标
├── Tools/IconMaker.swift         # 生成当前图标的脚本
├── scripts/                      # 构建、打包、安装脚本
├── docs/                         # 发布和维护文档
├── Makefile
├── PRIVACY.md
└── LICENSE
```
