# Maintenance

## Project Context

月白历是在一次针对 macOS 菜单栏农历日历的实际使用需求中做出来的。原始问题是旧工具 TinyCal / 小历在新版 macOS 菜单栏上文字颜色固定为黑色，无法跟随系统菜单栏颜色，视觉上不协调。

本项目选择做一个原生、轻量、颜色自适应的菜单栏日历工具，而不是修改旧 App 或 patch 二进制。

## Primary Conversation

维护本项目时优先回到这次项目对话检索上下文：

```text
019df1f6-375d-7f61-9be2-a1d102365727
```

该对话主要覆盖：

- TinyCal / 小历问题分析
- 月白历的第一版实现
- 菜单栏显示格式配置
- 月历弹窗设计
- 系统日历节假日联动
- 点击日期显示相对当前日期天数
- GitHub 仓库和 v1.0.0 release 发布

对话早期也包含过本机软件升级、CLI 升级和 GitHub CLI 登录等杂项，维护本项目时通常可以忽略。

## Product Decisions

- App 显示名：`月白历`
- Repository slug：`yuebaili`
- Bundle identifier：`local.yuebaili`
- macOS 最低版本：13.0
- App 类型：menu bar only，`LSUIElement = true`
- UI 技术：纯 AppKit，无 SwiftUI、无外部依赖
- 节假日来源：读取用户系统日历订阅，不硬编码国家法定节假日
- 权限：只请求日历权限
- 菜单栏右键：设置和退出
- 菜单栏左键：打开月历弹窗

## Current Behavior

菜单栏默认显示：

```text
日期 + 农历 + 星期
```

右键设置可切换：

- 显示日期
- 显示农历
- 显示星期
- 显示时间
- 显示秒数

开启秒数时每秒刷新；未开启秒数时每分钟刷新。

月历弹窗支持：

- 上一月 / 下一月
- 回到当前日期
- 打开系统日历
- 显示农历日
- 显示系统节假日订阅中的全天节假日事件
- 点击日期后在底部显示 `今天`、`N天前` 或 `N天后`
- 超过 9999 天显示 `9999+天前` 或 `9999+天后`

## Build And Release

常用命令：

```bash
make clean
make build
make verify
make package
```

本地安装：

```bash
make install
```

DMG 产物使用 ASCII 文件名：

```text
dist/Yuebaili-1.0.0.dmg
```

原因：GitHub Release 对中文附件名处理不稳定，曾把中文 DMG 名显示成 `-1.0.0.dmg`。

## GitHub

Repository:

```text
https://github.com/guozhixin88/yuebaili
```

Release:

```text
https://github.com/guozhixin88/yuebaili/releases/tag/v1.0.0
```

## Known Gaps

- App 名称和图标仍可继续打磨
- README 缺少截图
- 暂无 Developer ID 签名和 Apple notarization
- 暂无自动更新
- 暂无 Homebrew Cask
- 节假日识别依赖日历标题包含“节假日 / 假日 / holiday”
- 暂无独立设置窗口

## Documentation Rules

- 不把本机软件升级、CLI 升级等杂项写入项目历史
- 不硬编码具体年份的节假日
- 不在 README 首页放内部待办或分发风险提示
- 发布给普通用户前再处理签名、公证和更正式的安装说明
