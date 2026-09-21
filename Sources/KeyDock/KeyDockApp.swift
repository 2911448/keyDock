import AppKit
import SwiftUI
import Carbon

@main
enum KeyDockApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var panel: KeyboardPanel!
    private var statusItem: NSStatusItem!
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.keydock.app")
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        createApplicationMenu()
        createPanel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyDock")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "KeyDock · Option + 空格呼出键盘"
        model.onTogglePanel = { [weak self] in self?.togglePanel() }
        model.onShowPanel = { [weak self] in self?.showPanel() }
        model.onHidePanel = { [weak self] in self?.hidePanel() }
        model.onMenuChange = { [weak self] in self?.refreshMenu() }
        model.onShowSettings = { [weak self] in self?.showSettings() }
        model.onCloseSettings = { [weak self] in self?.settingsController?.close() }
        model.onExternalNavigation = { [weak self] in
            self?.hidePanel()
            self?.settingsController?.window?.orderBack(nil)
        }
        model.start()
        refreshMenu()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            if let self, self.model.sheet == nil, event.window !== self.panel { self.hidePanel() }
            return event
        }
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = launchEvent?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
            || launchEvent?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        if !launchedAtLogin || model.configurationNeedsRecovery {
            model.isEditing = model.configuration.bindings.isEmpty
            showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settingsController?.window?.isVisible == true { settingsController?.present() }
        else { showPanel() }
        return true
    }

    private func createPanel() {
        panel = KeyboardPanel()
        panel.onFocusLost = { [weak self] in self?.hidePanel() }
        panel.contentView = NSHostingView(rootView: KeyboardView(model: model))
    }

    private func createApplicationMenu() {
        let bar = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "KeyDock")
        let settings = NSMenuItem(title: "KeyDock 设置…", action: #selector(settingsAction), keyEquivalent: ",")
        settings.target = self
        applicationMenu.addItem(settings)
        applicationMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 KeyDock", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu
        bar.addItem(applicationItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("拷贝", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        editItem.submenu = editMenu
        bar.addItem(editItem)
        NSApp.mainMenu = bar
    }

    @objc private func togglePanel() {
        if model.isPanelVisible { hidePanel() } else { showPanel() }
    }

    private func showPanel() {
        settingsController?.window?.orderOut(nil)
        model.isSettingsFocused = false
        if !model.isPanelVisible {
            let foreground = NSWorkspace.shared.frontmostApplication
            if foreground?.processIdentifier != ProcessInfo.processInfo.processIdentifier { model.previousFrontmost = foreground }
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(CGFloat(1010), frame.width - 40)
            let height: CGFloat = 462 + (model.errorMessage == nil ? 0 : 42) + (model.showShortcutWarning ? 50 : 0)
            panel.setFrame(NSRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height), display: true)
        }
        model.isPanelVisible = true
        panel.makeKeyAndOrderFront(nil)

    }

    private func hidePanel() {
        guard model.isPanelVisible else { return }
        model.isPanelVisible = false
        model.sheet = nil
        panel.orderOut(nil)
        model.isEditing = false
    }

    @objc private func openPanelAction() { showPanel() }
    @objc private func editAction() { model.isEditing = true; showPanel() }
    private func showSettings() {
        hidePanel()
        if settingsController == nil {
            let controller = SettingsWindowController(contentView: NSHostingView(rootView: SettingsView(model: model)))
            controller.onFocusChange = { [weak self] focused in
                self?.model.isSettingsFocused = focused
                if focused { self?.model.monitor.refresh() }
            }
            settingsController = controller
        }
        settingsController?.present()
    }

    @objc private func settingsAction() { model.showSettings() }
    @objc private func pauseAction() { model.isPaused.toggle() }
    @objc private func loginAction() { model.setLoginEnabled(!model.loginEnabled) }
    @objc private func quitAction() { NSApp.terminate(nil) }

    private func refreshMenu() {
        guard statusItem != nil else { return }
        if model.isPanelVisible, let panel {
            let height: CGFloat = 462 + (model.errorMessage == nil ? 0 : 42) + (model.showShortcutWarning ? 50 : 0)
            if panel.frame.height != height {
                var frame = panel.frame
                frame.origin.y += (frame.height - height) / 2
                frame.size.height = height
                panel.setFrame(frame, display: true)
            }
        }
        let menu = NSMenu()
        let header = NSMenuItem(title: model.isPaused ? "KeyDock · 已暂停" : "KeyDock · \(model.listenerStatus)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        add("打开键盘面板", action: #selector(openPanelAction), to: menu)
        add("编辑绑定…", action: #selector(editAction), to: menu)
        add("设置…", action: #selector(settingsAction), to: menu)
        menu.addItem(.separator())
        add("暂停全局快捷键", action: #selector(pauseAction), to: menu, checked: model.isPaused)
        add("登录时启动", action: #selector(loginAction), to: menu, checked: model.loginEnabled)
        menu.addItem(.separator())
        add("退出 KeyDock", action: #selector(quitAction), to: menu)
        statusItem.menu = menu
        statusItem.button?.toolTip = "KeyDock · \(model.configuration.summonKey.title) + 空格呼出键盘"
    }
    private func add(_ title: String, action: Selector, to menu: NSMenu, checked: Bool = false) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; item.state = checked ? .on : .off
        menu.addItem(item)
    }
}
