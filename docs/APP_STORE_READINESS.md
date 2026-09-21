# KeyDock 商店发布记录

更新：2026-09-21。分支：`feat/app-store`。版本：1.2.0（build 8）。**build 8 已上传且 Apple 验证完成，并已关联发布版本；尚未提交审核或公开发布。**

## 已完成

- 2026-09-21：生成 K 键帽应用图标，保留原始 PNG 及生成提示词，产出全部 macOS 图标尺寸并接入 Xcode。build 8 已归档、图标/沙盒检查通过，于 18:17（Asia/Shanghai）上传成功；Apple 处理中。旧版图标文件保留。后续已在 App Store Connect 核验 build 8 为“完成 / 已验证”，构建选择器可见新 K 图标，已选择并保存至发布版本 1.2.0。仍提示缺少出口合规证明，需填写加密问卷。

- 从 1.1.0 基线新建商店分支；移除应用功能绑定的界面、菜单遍历、AX 点击、快捷键录制与模拟发送代码。
- 普通 App 绑定保留。隐藏仅使用 NSRunningApplication，不使用 AX 回退；系统未实际隐藏时报告失败。
- 全局监听改为 RegisterEventHotKey：只注册绑定和呼出组合，支持冲突反馈、长按去重、编辑/暂停释放及唤醒后重新注册。
- 呼出改为修饰键 + 空格，默认 Option；商店版前缀支持 Control/Option/Command，不提供双击和 Fn/Shift 前缀。
- 独立沙盒配置、Xcode 工程与共享 scheme、归档/导出脚本、应用图标、PrivacyInfo.xcprivacy 和 App 内隐私政策。
- 配置使用 v4，安全作用域书签支持手选 App。含旧应用功能的配置明确拒绝并保留原文件，普通旧格式保存前备份。
- `./scripts/test.sh`：21 项测试通过，包括冲突不误报成功、未注册键不触发、长按一次、暂停释放、恢复和配置变化、旧配置保护、书签往返、真实隐藏状态判断、窗口行为。
- 本地 Xcode archive 成功（unsigned 与团队开发签名归档均完成）。已于 2026-09-21 使用正式版 Xcode 27.0（27A266a）、SDK 26A425 重新归档，产物工具链字段已核对；21 项测试重新通过。
- 沙盒预览独立 Bundle ID：`io.keydock.app.storepreview`。签名权限与二进制检查通过：app-sandbox=true，无 AXUIElement / AXIsProcessTrusted / CGEventTapCreate / CGEventPost 链接，无 Apple Events 或临时例外 entitlement。
- 实机预览：无辅助功能授权提示；应用列表可读、搜索并保存 K→计算器、完成编辑后注册两个热键成功，鼠标调用后最近操作显示“已打开 / 显示 计算器”。预览配置在独立容器中保存，重启后 K→计算器绑定恢复。编辑状态明确显示暂停，不再误报注册冲突；键盘布局已检查。验证结束已退出预览版。
- 原本机 `dist/KeyDock.app` 1.1.0 及个人配置未覆盖。当前预览中的 K→计算器是测试配置，不是首次安装预设。

## 导出与上传进度（实际尝试结果）

Xcode 登录后，原先的 `No Accounts`、安装包发行证书和描述文件缺失问题已解决。

- `xcodebuild -exportArchive` 导出成功：`dist/store/export/KeyDock.pkg`。
- `pkgutil --check-signature` 验证签名链通过，安装包使用团队 `R97G9N5UN7` 的 Mac Developer Installer 发行证书签名。
- 首次命令行上传因 App Store Connect 缺少 `io.keydock.app` 的应用记录而失败。
- 已通过 Xcode Organizer 创建 KeyDock 应用记录：Bundle ID 和 SKU 均为 `io.keydock.app`，主语言为简体中文。首次 beta 归档上传失败；正式版归档重传结果如下。
- Apple 实际拒绝本次 Xcode 27 beta 5（27A5237l）构建：`This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode.`
- 正式版 Xcode 27.0（27A266a）已安装；重新编译归档、沙盒校验、导出与安装包签名链验证均通过。于 2026-09-21 18:01（Asia/Shanghai）通过命令行上传成功：`Upload succeeded`、`Uploaded KeyDock`、`EXPORT SUCCEEDED`。最终上传状态为 `Uploaded package is processing`；尚未确认 TestFlight 可用。
- Organizer 先前导入的是 beta 失败归档，未用它重传。本次上传直接使用重新生成的 `dist/store/KeyDock.xcarchive`，已核对 DTXcodeBuild=27A266a、DTSDKBuild=26A425。

## 恢复发布步骤

1. 账号、团队、应用记录、正式工具链及上传已完成；在 App Store Connect 确认 Apple 处理结果，处理通过后再安排 TestFlight。
2. 后续重建使用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，运行归档/导出脚本。系统 xcode-select 仍指向 CommandLineTools，本次没有修改全局选择。
3. 用户已确认名称 `keyDock`、免费及邮箱 `xin2911448@icloud.com`；版权资料整理为 `2026 keyDock`。销售地区待确认。
4. [隐私政策](https://github.com/2911448/keyDock/blob/feat/app-store/docs/store/privacy-policy.md)与[支持页面](https://github.com/2911448/keyDock/blob/feat/app-store/docs/store/support.md)已推送到公开 GitHub 仓库，并验证无需登录可读取。Safari 已登录；名称、副标题、效率分类及隐私政策 URL 已保存，版本描述、支持 URL、版权、审核备注和审核联系信息已填写保存。私人审核电话仅填写至 Apple，不记录到公开仓库。隐私问卷已保存为“不收集数据”，最终发布声明等待用户确认。免费价格已在 App Store Connect 保存；当前价格明细已核对为 $0.00 及对应地区的零元价格。销售地区尚未设置。
5. 完成下述实体环境验证与最终截图，完成 App Store Connect 上传校验、TestFlight、问卷和审核备注。默认建议手动发布；不把上传成功等同于上架。

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
