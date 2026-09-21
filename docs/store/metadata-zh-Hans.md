# App Store Connect 文案草稿

状态：已创建 KeyDock 商店记录（io.keydock.app，主语言简体中文），已使用正式版 Xcode 上传含新图标的 1.2.0（8），Apple 已验证，已关联至发布版本 1.2.0，尚未提交审核。用户已确认名称 keyDock、免费和联系邮箱；销售地区待确认。GitHub 隐私及支持页面已公开发布并验证无需登录可读取。名称、副标题、效率分类、隐私政策 URL 已保存到 App Store Connect。版本描述、支持 URL、版权、审核备注及用户提供的审核联系信息已填写保存；私人审核电话不写入仓库。免费价格已在 App Store Connect 保存；当前价格明细已核对为 $0.00 及对应地区的零元价格。销售地区尚未设置。隐私问卷已保存为“不收集数据”，发布声明等待用户确认。

- 名称：keyDock
- 副标题：把常用应用放到键盘上
- 分类：效率
- 关键词：快捷键,启动器,键盘,应用切换,菜单栏,效率
- 平台：macOS 14+，Apple Silicon
- 版本：1.2.0（build 8，含新图标，已于 2026-09-21 上传）
- 隐私政策 URL：https://github.com/2911448/keyDock/blob/feat/app-store/docs/store/privacy-policy.md
- 支持 URL：https://github.com/2911448/keyDock/blob/feat/app-store/docs/store/support.md
- 支持及隐私联系邮箱：xin2911448@icloud.com
- 版权：2026 keyDock
- 定价：免费（0）
- 销售地区：待确认

## 描述

把常用 Mac 应用放到熟悉的键盘位置，少找一次图标，多一点专注。

KeyDock 是一个菜单栏应用启动器。为字母、数字和标点键选择应用，即可用统一前缀加按键快速调用，也可以打开半透明键盘面板，直接按键或点击图标。

• 应用未运行时启动，在后台时切到前台。
• 再次调用前台应用时请求隐藏；应用未响应时会提示。
• 默认 Option + 空格呼出键盘面板，可在设置更换呼出组合。
• 支持本机应用搜索、手动选择、替换和清除绑定。
• 支持深浅色、暂停快捷键和可选登录启动。
• 沙盒运行，无需辅助功能权限；配置只保存在本机。

首次使用请点击菜单栏键盘图标，进入编辑，配置自己的第一个按键。全局快捷键可能与系统或其他软件冲突，可在设置查看并调整。

商店版仅用于应用启动与切换，不提供应用内部功能操作、模拟按键或菜单栏图标收纳。

## 审核备注（英文草稿）

KeyDock is a menu bar application launcher. No account or subscription is required to use the app. On first launch it shows an empty keyboard in editing mode. Click a letter key, select an installed application, then click Done. The default app shortcut prefix is Control. Option-Space toggles the panel; both settings can be changed.

Only configured shortcuts are registered using RegisterEventHotKey. KeyDock does not request Accessibility or Input Monitoring access, read other applications' menus, or generate keyboard input. Editing, focused settings, and the Pause option release the global registrations. Conflicts are reported in Settings.

The app uses NSWorkspace to open applications and NSRunningApplication.hide to request hiding. A target app may refuse to hide; KeyDock reports that outcome instead of using Accessibility as a fallback. The menu bar menu always provides access to the keyboard, settings, and Quit.

Login at startup is off by default and is enabled only by the user with SMAppService. Configuration and user-selected application bookmarks remain in the sandbox container.

## 截图计划

使用最终商店版真实截图：配置了普通应用的键盘面板、应用搜索绑定界面、快捷键与冲突设置。不要复用展示应用功能绑定或菜单栏收纳的旧截图。截图完成前先去除测试警告和个人敏感信息。
