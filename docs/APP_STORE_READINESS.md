# KeyDock 商店发布记录

更新：2026-09-21。分支：`feat/app-store`。版本：1.2.0（build 7）。**尚未上传、提交审核或公开发布。**

## 已完成

- 从 1.1.0 基线新建商店分支；移除应用功能绑定的界面、菜单遍历、AX 点击、快捷键录制与模拟发送代码。
- 普通 App 绑定保留。隐藏仅使用 NSRunningApplication，不使用 AX 回退；系统未实际隐藏时报告失败。
- 全局监听改为 RegisterEventHotKey：只注册绑定和呼出组合，支持冲突反馈、长按去重、编辑/暂停释放及唤醒后重新注册。
- 呼出改为修饰键 + 空格，默认 Option；商店版前缀支持 Control/Option/Command，不提供双击和 Fn/Shift 前缀。
- 独立沙盒配置、Xcode 工程与共享 scheme、归档/导出脚本、应用图标、PrivacyInfo.xcprivacy 和 App 内隐私政策。
- 配置使用 v4，安全作用域书签支持手选 App。含旧应用功能的配置明确拒绝并保留原文件，普通旧格式保存前备份。
- `./scripts/test.sh`：21 项测试通过，包括冲突不误报成功、未注册键不触发、长按一次、暂停释放、恢复和配置变化、旧配置保护、书签往返、真实隐藏状态判断、窗口行为。
- 本地 Xcode archive 成功（unsigned 与团队开发签名归档均完成）。本机工具链为 Xcode 27.0 / 27A5237l；上架前仍需核对 Apple 接受的正式工具链。
- 沙盒预览独立 Bundle ID：`io.keydock.app.storepreview`。签名权限与二进制检查通过：app-sandbox=true，无 AXUIElement / AXIsProcessTrusted / CGEventTapCreate / CGEventPost 链接，无 Apple Events 或临时例外 entitlement。
- 实机预览：无辅助功能授权提示；应用列表可读、搜索并保存 K→计算器、完成编辑后注册两个热键成功，鼠标调用后最近操作显示“已打开 / 显示 计算器”。预览配置在独立容器中保存，重启后 K→计算器绑定恢复。编辑状态明确显示暂停，不再误报注册冲突；键盘布局已检查。验证结束已退出预览版。
- 原本机 `dist/KeyDock.app` 1.1.0 及个人配置未覆盖。当前预览中的 K→计算器是测试配置，不是首次安装预设。

## 导出阻碍（实际尝试结果）

`xcodebuild -exportArchive` 返回：

- `No Accounts`：Xcode 未配置可用的开发者账号。
- `No signing certificate "Mac Installer Distribution" found`：缺少团队安装包发行证书及私钥。
- `No profiles for 'io.keydock.app' were found`：缺少此 Bundle ID 的 Mac App Store 描述文件。

本机 Apple Distribution 证书本身不能替代上述账号、安装包签名和配置文件。请在 Xcode Settings → Accounts 登录付费开发者账号，再检查团队、Bundle ID 所属和证书。无需向聊天发送密码、验证码或私钥。

## 恢复发布步骤

1. Xcode 登录完成；确认该团队可使用 `io.keydock.app`，签发/下载商店描述文件及所需发行证书。
2. 选择 Apple 当前接受的 Xcode/SDK，运行 `scripts/store/build.sh archive` 和 `export`。见 README 的环境变量说明。
3. 补齐 [商店资料](store/metadata-zh-Hans.md)：开发者/版权名称、支持邮箱或网址、定价、销售地区、隐私政策公开 URL。当前草稿不可直接提交。
4. 完成下述实体环境验证与最终截图，再建立/选择 App Store Connect 记录，上传校验、TestFlight、问卷和审核备注。默认建议手动发布；不把上传成功等同于上架。

## 未完成的功能验收

全局热键注册成功不等于实体按键触发已验证。仍需实体键盘验证后台 Control+K、Option+空格、重复隐藏/恢复、长按、冲突、更换前缀、中文输入法、睡眠唤醒及全屏/多屏。此前 1.1.0 的验收不能替代新后端验证。

NSRunningApplication.hide 的真实目标应用兼容性尚未在商店沙盒版确认；不宣称微信可可靠隐藏。文件选择后重启书签、应用移动/卸载、最低支持 macOS 14、登录启动、正式签名包重装也待验证。

## 隐私检查范围

源码不直接使用 UserDefaults、系统启动时长、文件时间戳、磁盘可用空间或键盘布局枚举等需说明理由的 API。PrivacyInfo.xcprivacy 声明无追踪、无收集、空 required-reason API 列表。文件枚举仅请求 isDirectoryKey，未读取文件时间。新增 SDK 或 API 后必须重新检查，不能将当前声明用于未审计的新功能。

## 官方依据

- [Mac App Store 沙盒及隐私政策要求](https://developer.apple.com/app-store/review/guidelines/)
- [App Sandbox 限制](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [上传构建](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [提交 App Store](https://developer.apple.com/app-store/submitting/)
