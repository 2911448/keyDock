import AppKit
import ServiceManagement
import KeyDockCore

final class AppModel: ObservableObject {
    @Published private(set) var configuration = Configuration()
    @Published var isEditing = false { didSet { updateGestureAvailability() } }
    @Published var isPaused = false { didSet { updateGestureAvailability(); onMenuChange?() } }
    @Published var isPanelVisible = false
    @Published var isSettingsFocused = false { didSet { updateGestureAvailability() } }
    @Published var sheet: PanelSheet? { didSet { updateGestureAvailability() } }
    var showShortcutWarning: Bool { !listenerActive && !isPaused && !isEditing && sheet == nil && !isSettingsFocused }
    @Published var listenerActive = false
    @Published var listenerStatus = "正在注册快捷键…"
    @Published var globalEventCount = 0
    @Published var summonCount = 0
    @Published var lastAction = "尚未调用应用"
    @Published var errorMessage: String?
    @Published var configurationNeedsRecovery = false
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    let catalog = ApplicationCatalog()
    let monitor = KeyboardMonitor()
    let repository: ConfigurationRepository
    var onTogglePanel: (() -> Void)?
    var onShowPanel: (() -> Void)?
    var onHidePanel: (() -> Void)?
    var onMenuChange: (() -> Void)?
    var onShowSettings: (() -> Void)?
    var onCloseSettings: (() -> Void)?
    var onExternalNavigation: (() -> Void)?
    var previousFrontmost: NSRunningApplication?
    private var pendingApplications = Set<String>()
    private var scopedURLs: [Data: URL] = [:]

    enum PanelSheet: String, Identifiable {
        case appPicker
        var id: String { rawValue }
    }
    @Published var selectedKey: UInt16 = 0

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("KeyDock", isDirectory: true)
        repository = ConfigurationRepository(url: directory.appendingPathComponent("settings.json"))
        do { configuration = try repository.load() }
        catch { configurationNeedsRecovery = true; errorMessage = "无法读取配置，原文件已保留：\(error.localizedDescription)" }
        refreshLoginStatus()
    }

    func start() {
        monitor.configure(configuration)
        monitor.onKeyDown = { [weak self] code, flags, repeated in self?.handleKey(code, flags: flags, repeated: repeated) ?? false }
        monitor.onSummon = { [weak self] in
            DispatchQueue.main.async { self?.summonCount += 1; self?.onTogglePanel?() }
        }
        monitor.onEventCount = { [weak self] count in
            if self?.globalEventCount != count { self?.globalEventCount = count }
        }
        monitor.onStatus = { [weak self] active, status in
            self?.listenerActive = active; self?.listenerStatus = status; self?.onMenuChange?()
        }
        monitor.start()
        catalog.reload()
    }

    func binding(for keyCode: UInt16) -> AppBinding? { configuration.bindings.first { $0.keyCode == keyCode } }
    func selectKey(_ code: UInt16) {
        guard PhysicalKeys.labels[code] != nil else { return }
        if isEditing { selectedKey = code; sheet = .appPicker }
        else { trigger(code) }
    }
    func assign(_ app: CatalogApp, bookmark: Data? = nil) {
        var updated = configuration
        updated.bindings.removeAll { $0.keyCode == selectedKey }
        updated.bindings.append(AppBinding(keyCode: selectedKey, bundleIdentifier: app.bundleIdentifier, path: app.url.path, name: app.name, bookmark: bookmark))
        if persist(updated) { sheet = nil }
    }
    func clearSelectedBinding() {
        var updated = configuration
        updated.bindings.removeAll { $0.keyCode == selectedKey }
        if persist(updated) { sheet = nil }
    }
    func setPrefix(_ modifier: Modifier) {
        var updated = configuration; updated.prefix = modifier
        _ = persist(updated)
    }
    func setSummonKey(_ modifier: Modifier) {
        var updated = configuration; updated.summonKey = modifier
        _ = persist(updated)
    }
    @discardableResult private func persist(_ updated: Configuration) -> Bool {
        guard !configurationNeedsRecovery else { errorMessage = "请先在设置中备份并重置损坏的配置。"; return false }
        do { try repository.save(updated); configuration = updated; monitor.configure(updated); onMenuChange?(); return true }
        catch { errorMessage = "配置保存失败：\(error.localizedDescription)"; return false }
    }
    func recoverConfiguration() {
        do {
            let backup = try repository.backupAndReset()
            configurationNeedsRecovery = false; configuration = Configuration(); monitor.configure(configuration)
            errorMessage = "配置已重置，原文件备份为 \(backup.lastPathComponent)"
        } catch { errorMessage = "备份或重置失败，原配置未主动删除：\(error.localizedDescription)" }
    }

    private func updateGestureAvailability() {
        monitor.gesturesEnabled = !isEditing && !isPaused && sheet == nil && !isSettingsFocused
    }

    private func handleKey(_ code: UInt16, flags: KeyModifiers, repeated: Bool) -> Bool {
        guard sheet == nil && !isSettingsFocused else { return false }
        if isPanelVisible, code == 53 {
            if !repeated { onHidePanel?() }
            return true
        }
        guard !isEditing else { return false }
        let panelMatch = isPanelVisible && (flags.isEmpty || flags == configuration.prefix.mask) && binding(for: code) != nil
        let globalMatch = ShortcutRouter.matches(keyCode: code, modifiers: flags, configuration: configuration, paused: isPaused, editing: isEditing)
        guard panelMatch || globalMatch else { return false }
        if !repeated {
            // Leave the hotkey callback immediately; workspace and UI actions run on the next turn.
            DispatchQueue.main.async { [weak self] in self?.trigger(code) }
        }
        return true
    }

    private func resolvedURL(for binding: AppBinding) -> URL? {
        if let data = binding.bookmark {
            if let cached = scopedURLs[data] { return cached }
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale),
               url.startAccessingSecurityScopedResource() {
                if let app = ApplicationCatalog.application(at: url), binding.bundleIdentifier == nil || app.bundleIdentifier == binding.bundleIdentifier {
                    scopedURLs[data] = url
                    return url
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
        let storedURL = URL(fileURLWithPath: binding.path)
        if let app = ApplicationCatalog.application(at: storedURL), binding.bundleIdentifier == nil || app.bundleIdentifier == binding.bundleIdentifier { return storedURL }
        if let identifier = binding.bundleIdentifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier), ApplicationCatalog.application(at: url) != nil { return url }
        return nil
    }

    func trigger(_ code: UInt16) {
        guard let binding = binding(for: code) else { return }
        guard let url = resolvedURL(for: binding) else {
            errorMessage = "找不到“\(binding.name)”，请进入编辑模式重新选择 App。"; onShowPanel?(); return
        }
        let token = binding.bundleIdentifier ?? url.path
        guard !pendingApplications.contains(token) else { return }
        if url.path != binding.path {
            var updated = configuration
            if let index = updated.bindings.firstIndex(where: { $0.keyCode == code }) { updated.bindings[index].path = url.path; _ = persist(updated) }
        }
        let foreground = isPanelVisible ? previousFrontmost : NSWorkspace.shared.frontmostApplication
        let running = NSWorkspace.shared.runningApplications.first { app in
            if let identifier = binding.bundleIdentifier { return app.bundleIdentifier == identifier && !app.isTerminated }
            return app.bundleURL?.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() && !app.isTerminated
        }
        let action = ApplicationAction.decide(isRunning: running != nil, isHidden: running?.isHidden ?? false,
                                             wasFrontmost: running != nil && running?.processIdentifier == foreground?.processIdentifier)
        errorMessage = nil
        onHidePanel?()
        if action == .hide, let running {
            pendingApplications.insert(token)
            Task { @MainActor [weak self] in
                let hidden = await ApplicationHider.hide(running)
                guard let self else { return }
                self.pendingApplications.remove(token)
                if hidden { self.lastAction = "已隐藏 \(binding.name)" }
                else { self.showLaunchError("无法隐藏“\(binding.name)”，应用未响应隐藏请求。") }
            }
            return
        }
        // Opening a running app also reopens its window if all windows were closed.
        pendingApplications.insert(token)
        let options = NSWorkspace.OpenConfiguration()
        options.activates = true
        options.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: options) { [weak self] _, error in
            DispatchQueue.main.async {
                self?.pendingApplications.remove(token)
                if let error { self?.showLaunchError("无法打开“\(binding.name)”：\(error.localizedDescription)") }
                else { self?.lastAction = "已打开 / 显示 \(binding.name)" }
            }
        }
    }
    private func showLaunchError(_ message: String) { lastAction = message; errorMessage = message; onShowPanel?() }

    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }
    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = "开机启动设置失败：\(error.localizedDescription)" }
        refreshLoginStatus(); onMenuChange?()
    }

    deinit { scopedURLs.values.forEach { $0.stopAccessingSecurityScopedResource() } }

    func showSettings() { refreshLoginStatus(); onShowSettings?() }
}
