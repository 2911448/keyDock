# KeyDock · Mac App Store 分支

把常用 Mac 应用放到键盘上，通过组合键或键盘面板快速调用。

本分支 `feat/app-store` 是 1.2.0（build 7）的商店适配版本。完整版本保留在 `feat/keydock`。当前已完成本地沙盒预览、Xcode 归档和自动检查，**尚未提交商店审核**。当前发行阻碍及实测范围见 [发布记录](docs/APP_STORE_READINESS.md)。

## 商店版功能

- 字母、数字和标点键绑定普通应用，同一应用可绑定多个键。
- 统一前缀支持 Control、Option、Command；只注册已绑定组合，发生冲突时显示具体按键。
- 未运行则启动，后台则激活，前台则请求隐藏；应用拒绝隐藏时提示失败。
- 默认 **Option + 空格** 呼出或关闭面板，也可在设置改成 Control / Command + 空格。注意系统或其他软件可能已占用这些组合。
- 面板内按物理键位或点击键帽调用应用；Esc、点击外部可关闭。
- 半透明键盘面板、深浅色、鼠标所在屏幕定位、本机自动保存、可选登录启动。
- 沙盒运行，通过系统热键注册，无需辅助功能授权。不记录键盘输入，不上传绑定。

商店版不包含应用菜单读取、应用功能绑定、模拟快捷键发送、双击修饰键、Fn/Shift 前缀或菜单栏图标收纳。

## 使用

1. 点击菜单栏键盘图标 → 编辑绑定，选择键帽，再搜索并选择应用；列表找不到时用“从文件选择”。
2. 点击“完成”，用默认 Control + 对应键调用应用。
3. 按 Option + 空格打开面板，直接按键或点键帽。
4. 通过设置查看热键注册结果、更换前缀和呼出组合。搜索、编辑、设置聚焦和暂停时会释放全局热键，普通输入不被截获。

详细说明：[使用指南](docs/USAGE.md)。

## 本地构建和验证

Apple Silicon，macOS 14+，完整 Xcode。首次安装没有预设绑定。

```sh
./scripts/test.sh
./scripts/build.sh
```

`build.sh` 使用 Xcode 生成隔离预览包：`dist/store-preview/KeyDock Store Preview.app`，Bundle ID 为 `io.keydock.app.storepreview`。它使用开发证书和真实沙盒权限，不覆盖 `dist/KeyDock.app` 或原版本配置。运行后可与原版本区分，但同时启动可能发生快捷键冲突。该预览包不能上传商店。

Xcode 工程是 `KeyDock.xcodeproj`，KeyDockCore 仍由本地 Swift Package 提供。增删 App 源文件后运行 `python3 scripts/store/generate-project.py` 更新工程。

## 商店归档和导出

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export KEYDOCK_TEAM_ID=你的开发者团队ID
./scripts/store/build.sh archive
./scripts/store/build.sh export
```

发行构建需选择 Apple 接受的 Xcode/SDK、在 Xcode 登录开发者账号并具备所需证书与商店描述文件。归档位于 `dist/store/KeyDock.xcarchive`，导出位于 `dist/store/export/`。导出脚本不会自动上传或发布。

`verify-bundle.py` 检查签名、沙盒权限、隐私清单、图标和被移除的跨应用控制符号。它不能替代 App Store Connect 校验或真机操作测试。

## 配置与隐私

商店版配置格式为 v4，保存在系统应用容器内的 Application Support/KeyDock/settings.json。请从设置中“在 Finder 中显示”定位。

不会自动读取完整版本的配置。含应用功能或内置动作的旧配置会被拒绝，保留原文件；不悄悄改成普通应用启动。可读取仅含普通应用、且修饰键受支持的 v1/v2 配置，首次保存前备份原文件。文件选择器绑定会保存安全作用域书签。

[隐私政策草稿](docs/store/privacy-policy.md) · [商店文案和审核备注](docs/store/metadata-zh-Hans.md) · [验证记录](docs/QA.md)
