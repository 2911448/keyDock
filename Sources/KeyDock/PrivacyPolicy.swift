import AppKit
import SwiftUI

extension AppModel {
    func showPrivacyPolicy() {
        PrivacyPolicyWindow.shared.present()
    }
}

private final class PrivacyPolicyWindow {
    static let shared = PrivacyPolicyWindow()
    private var controller: NSWindowController?
    func present() {
        if controller == nil {
            let text = """
            KeyDock 隐私政策

            KeyDock 在本机处理应用绑定与快捷键，不向开发者上传这些内容。

            • 保存的数据：所选应用的名称、标识、路径、按键设置，以及手动选择应用后用于恢复访问的系统书签。它们保存在本机应用容器中。
            • 按键处理：只注册你配置的全局组合键，以及面板呼出组合键；面板中处理用于操作界面的按键。不记录键盘输入内容。
            • 数据共享：不提供账号、广告、统计、云同步或第三方分析服务。
            • 删除与控制：可清除单个绑定、暂停快捷键或退出应用；需要删除全部配置时，可从设置定位配置文件，退出后删除它。开机启动可随时关闭。
            • 反馈：如主动向项目提交问题，你提供的内容会由相应支持平台处理。请勿提交密码或不必要的个人信息。

            本政策适用于 KeyDock 商店版。政策日期：2026-09-21。
            """
            let view = ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(24) }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 480), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "KeyDock 隐私政策"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            controller = NSWindowController(window: window)
        }
        NSApp.activate()
        controller?.showWindow(nil)
    }
}
