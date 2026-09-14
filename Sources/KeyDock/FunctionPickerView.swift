import SwiftUI
import AppKit
import KeyDockCore

final class FunctionDraft: ObservableObject {
    @Published var isFunction = false
    @Published var app: CatalogApp?
    @Published var manual = false
    @Published var name = ""
    @Published var shortcut: RecordedShortcut?
    @Published var activateFirst = true
    @Published var menuPath: [String] = []
    @Published var functions: [DiscoveredMenuFunction] = []
    @Published var query = ""
    @Published var loading = false
    @Published var status = ""
    private var generation = UUID()
    var function: AppFunction? {
        let result = manual ? AppFunction(kind: .shortcut, name: name, shortcut: shortcut, activateFirst: activateFirst)
            : AppFunction(kind: .menu, name: menuPath.last ?? "", menuPath: menuPath)
        return result.isValid ? result : nil
    }
    func reset(binding: AppBinding?) {
        generation = UUID(); loading = false; isFunction = binding?.function != nil
        app = nil; manual = false; name = ""; shortcut = nil; activateFirst = true
        menuPath = []; functions = []; query = ""; status = ""
        if let binding, let function = binding.function {
            app = ApplicationCatalog.application(at: URL(fileURLWithPath: binding.path))
                ?? binding.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.flatMap { ApplicationCatalog.application(at: $0) }
                ?? CatalogApp(url: URL(fileURLWithPath: binding.path), name: binding.name, bundleIdentifier: binding.bundleIdentifier)
            manual = function.kind == .shortcut; name = function.name
            shortcut = function.shortcut; activateFirst = function.activateFirst; menuPath = function.menuPath
        }
    }
    func selectApp(_ app: CatalogApp) {
        reset(binding: nil); isFunction = true; self.app = app
    }
    @MainActor func refresh(launch: Bool = false) async {
        guard let app, !loading else { return }
        loading = true; status = ""; functions = []
        let token = generation
        defer { if token == generation { loading = false } }
        do {
            var running = NSWorkspace.shared.runningApplications.first {
                $0.bundleURL?.resolvingSymlinksInPath() == app.url.resolvingSymlinksInPath() && !$0.isTerminated
            }
            if running == nil && launch {
                let options = NSWorkspace.OpenConfiguration(); options.activates = false
                running = try await NSWorkspace.shared.openApplication(at: app.url, configuration: options)
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            guard let running else { status = "应用尚未运行。点击「启动并读取」，或直接手动添加快捷键。"; return }
            let result = try await MenuFunctions.scan(pid: running.processIdentifier)
            guard generation == token, !Task.isCancelled else { return }
            functions = result.functions
            status = result.partial ? "已显示部分功能，应用响应较慢。可稍后刷新。" : "发现 \(functions.count) 个菜单功能。灰色功能当前不可用；同名完整路径会被排除。"
            if functions.isEmpty { status += " 若应用未暴露菜单，可手动添加快捷键。" }
        } catch { if token == generation { status = error.localizedDescription } }
    }
}

struct FunctionPickerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var draft: FunctionDraft
    let app: CatalogApp
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: model.catalog.icon(at: app.url.path)).resizable().frame(width: 28, height: 28)
                Text(app.name).font(.headline)
                Spacer()
                Button("更换 App") { draft.selectApp(app); draft.app = nil }
            }
            Picker("功能来源", selection: $draft.manual) {
                Text("自动发现菜单").tag(false)
                Text("手动添加快捷键").tag(true)
            }.pickerStyle(.segmented)
            if draft.manual {
                TextField("功能名称，例如：微信截图", text: $draft.name).textFieldStyle(.roundedBorder)
                ShortcutRecorder(shortcut: $draft.shortcut, keyboardMonitor: model.monitor).frame(height: 42)
                Picker("执行方式", selection: $draft.activateFirst) {
                    Text("先激活应用，再执行").tag(true)
                    Text("后台触发（仅限应用的全局快捷键）").tag(false)
                }
                Text("请录入目标应用实际配置的快捷键。支持 ⌃ / ⌥ / ⌘ 与其他键组合，或单独 F1–F12；Esc 取消录入。微信截图若支持全局调用，可选择后台触发。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                HStack {
                    TextField("搜索功能名称或菜单路径…", text: $draft.query).textFieldStyle(.roundedBorder)
                    Button("刷新") { Task { await draft.refresh() } }.disabled(draft.loading)
                    Button("启动并读取") { Task { await draft.refresh(launch: true) } }.disabled(draft.loading)
                }
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if !draft.loading && draft.functions.filter({ draft.query.isEmpty || $0.breadcrumb.localizedCaseInsensitiveContains(draft.query) }).isEmpty {
                            Text(draft.query.isEmpty ? "暂无可读取的菜单功能" : "没有匹配的菜单功能，可尝试其他名称或手动添加快捷键。")
                                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 24)
                        }
                        ForEach(draft.functions.filter { draft.query.isEmpty || $0.breadcrumb.localizedCaseInsensitiveContains(draft.query) }) { item in
                            Button { draft.menuPath = item.path } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).font(.system(size: 13, weight: .medium))
                                        Text(item.breadcrumb).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.shortcutLabel).font(.caption)
                                    if draft.menuPath == item.path { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(item.enabled ? Color.primary : Color.secondary)
                                    .background(draft.menuPath == item.path ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                                    .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !draft.menuPath.isEmpty {
                    Text("已选：\(draft.menuPath.joined(separator: " → "))").font(.caption).lineLimit(2)
                }
            }
            if draft.loading { ProgressView("正在读取菜单…").controlSize(.small) }
            if !draft.status.isEmpty { Text(draft.status).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
            HStack {
                Text("测试会收起面板；再次呼出可继续编辑。").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("测试") {
                    if let function = draft.function { model.testFunction(function, app: app) }
                }.disabled(draft.function == nil || model.functionInProgress)
                Button("保存绑定") {
                    if let function = draft.function { model.assign(app, function: function) }
                }.disabled(draft.function == nil).buttonStyle(.borderedProminent)
            }
        }.task(id: app.id) { if !draft.manual && draft.functions.isEmpty { await draft.refresh() } }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: RecordedShortcut?
    let keyboardMonitor: KeyboardMonitor
    func makeNSView(context: Context) -> RecorderButton { RecorderButton() }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.keyboardMonitor = keyboardMonitor
        view.onRecord = { shortcut = $0 }
        view.value = shortcut
        if !view.recording { view.title = shortcut.map { "\($0.label) · 点击重新录入" } ?? "点击这里，然后按下目标快捷键" }
    }
}

final class RecorderButton: NSButton {
    var value: RecordedShortcut?
    var onRecord: ((RecordedShortcut) -> Void)?
    weak var keyboardMonitor: KeyboardMonitor?
    private(set) var recording = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded; target = self; action = #selector(beginRecording)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func beginRecording() {
        stop(); recording = true; title = "请按快捷键…（Esc 取消）"
        keyboardMonitor?.onRecordKeyDown = { [weak self] code, flags in
            // Return from the event tap before updating SwiftUI or ending recording.
            DispatchQueue.main.async { [weak self] in self?.record(code, flags: flags) }
        }
    }
    private func record(_ code: UInt16, flags: KeyModifiers) {
        guard recording else { return }
        if code == 53 { stop(); return }
        let normalized = RecordedShortcut.specialLabels[code]?.hasPrefix("F") == true ? flags.subtracting(.function) : flags
        let shortcut = RecordedShortcut(keyCode: code, modifiers: normalized.rawValue)
        if shortcut.isValid { value = shortcut; onRecord?(shortcut); stop() }
        else { title = "请使用 ⌃ / ⌥ / ⌘ 组合键，或 F1–F12" }
    }
    private func stop() {
        keyboardMonitor?.onRecordKeyDown = nil
        recording = false
        title = value.map { "\($0.label) · 点击重新录入" } ?? "点击这里，然后按下目标快捷键"
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { stop() }; super.viewWillMove(toWindow: newWindow) }
    deinit { keyboardMonitor?.onRecordKeyDown = nil }
}
