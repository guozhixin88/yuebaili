# Release Checklist

## 本地检查

- `make clean`
- `make build`
- `make verify`
- `make package`
- 安装 DMG 后首次启动
- 授权日历权限
- 确认能读取“中国大陆节假日”等系统日历订阅
- 确认右键设置可保存
- 确认开启秒数后每秒刷新

## 分发前

- 确认 App 名称和图标
- 更新 `CHANGELOG.md`
- 更新 README 截图
- 如果面向公开用户分发，使用 Developer ID 签名和 Apple notarization

## GitHub

- 创建 GitHub repo
- 推送源码
- 创建 release
- 上传 DMG
- 在 README 中补充下载链接

