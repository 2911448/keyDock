import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import KeyDockCore

struct AppPickerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var catalog: ApplicationCatalog
    @ObservedObject var draft: FunctionDraft
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    private var filtered: [CatalogApp] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? catalog.apps : catalog.apps.filter { $0.name.localizedCaseInsensitiveContains(query) || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(query) ?? false) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(PhysicalKeys.labels[model.selectedKey] ?? "")
                    .font(.system(size: 25, weight: .medium, design: .rounded)).frame(width: 48, height: 48)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("绑定应用或应用功能").font(.headline)
                    Text("\(model.configuration.prefix.symbol) + \(PhysicalKeys.labels[model.selectedKey] ?? "") · \(draft.isFunction ? "执行应用功能" : "启动 / 显示 / 隐藏")")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.sheet = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("关闭应用选择")
            }
            Picker("绑定类型", selection: $draft.isFunction) {
                Text("应用 · 唤起 / 隐藏").tag(false)
                Text("应用功能").tag(true)
            }.pickerStyle(.segmented)
            if draft.isFunction, let app = draft.app {
                FunctionPickerView(model: model, draft: draft, app: app)
            } else {
                TextField("搜索应用名称…", text: $search).textFieldStyle(.roundedBorder).focused($searchFocused)
                if let message = model.errorMessage {
                    Text(message).font(.caption).foregroundStyle(.orange).lineLimit(2)
                }
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filtered) { app in
                            Button { select(app) } label: {
                                HStack(spacing: 12) {
                                    Image(nsImage: catalog.icon(at: app.url.path)).resizable().frame(width: 32, height: 32)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(app.name).font(.system(size: 13, weight: .medium))
                                        Text(app.url.path).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    if model.binding(for: model.selectedKey)?.path == app.url.path {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                    }
                                }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("绑定 \(app.name)")
                        }
                        if filtered.isEmpty {
                            VStack(spacing: 10) {
                                if catalog.isLoading { ProgressView().controlSize(.small) }
                                Text(catalog.isLoading ? "正在查找本机应用…" : "没有找到应用，可从文件中选择。")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(.top, 70)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("从文件选择…", action: chooseFile)
                Button { catalog.reload() } label: { Image(systemName: "arrow.clockwise") }.help("刷新应用列表")
                Spacer()
                if model.binding(for: model.selectedKey) != nil {
                    Button("清除绑定", role: .destructive) { model.clearSelectedBinding() }
                }
                Button("取消") { model.sheet = nil }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24).frame(width: 600, height: 640)
        .onAppear { searchFocused = true }
    }
    private func select(_ app: CatalogApp) {
        if draft.isFunction { draft.selectApp(app) } else { model.assign(app) }
    }
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "选择 App"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let app = ApplicationCatalog.application(at: url), app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                model.errorMessage = "请选择一个有效的其他应用。"; return
            }
            select(app)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("让快捷键顺手起来").font(.system(size: 20, weight: .semibold))
                    Text("设置立即生效，只保存在这台 Mac 上。").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { model.onCloseSettings?() }.keyboardShortcut(.cancelAction)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("快捷键") {
                        settingsRow("统一前缀键", detail: "前缀 + 字母、数字或标点，调用对应 App。") {
                            Picker("统一前缀键", selection: Binding(get: { model.configuration.prefix }, set: model.setPrefix)) {
                                ForEach(Modifier.allCases) { Text("\($0.symbol)  \($0.title)").tag($0) }
                            }.labelsHidden().frame(width: 170)
                        }
                        settingsRow("双击呼出键", detail: "350 毫秒内单独连按两次，不与其他键混按。") {
                            Picker("双击呼出键", selection: Binding(get: { model.configuration.summonKey }, set: model.setSummonKey)) {
                                ForEach(Modifier.allCases) { Text("\($0.symbol)  \($0.title)").tag($0) }
                            }.labelsHidden().frame(width: 170)
                        }
                        Text("已绑定的组合键由 KeyDock 优先处理，例如绑定 ⌘A 会影响“全选”。部分系统快捷键无法覆盖；未绑定按键正常传递。")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Toggle("暂停全局快捷键", isOn: $model.isPaused)
                            .toggleStyle(.switch).controlSize(.small)
                    }
                    section("系统权限") {
                        HStack {
                            Image(systemName: model.listenerActive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(model.listenerActive ? .green : .orange)
                            Text(model.listenerStatus).font(.system(size: 12, weight: .medium))
                            Spacer()
                            Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                        }
                        Text("后台快捷键、双击呼出和再次按键隐藏，都依赖全局监听。如果系统中的开关已开启，但此处仍未生效，请先关闭再开启 KeyDock 的辅助功能开关，再点击「重新检测」。更新过 App 后仍失败时，请在系统列表中移除旧 KeyDock，重新添加当前正在运行的 App 并开启授权。")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button("重新检测") { model.monitor.retry() }
                            Button("显示当前 App") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                        }
                        Text("收到全局按键事件：\(model.globalEventCount) · 识别双击：\(model.summonCount)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        Text("最近操作：\(model.lastAction)").font(.caption).foregroundStyle(.secondary)
                    }
                    if model.configuration.prefix == .function || model.configuration.summonKey == .function {
                        section("Fn / 地球键检测") {
                            Label(model.globeDetected ? "已收到地球键事件" : "单独按一下地球键以检测", systemImage: model.globeDetected ? "checkmark.circle" : "globe")
                            Text("如果同时弹出表情、输入法或听写，请在系统键盘设置中调整地球键行为。部分外接键盘不会向系统发送 Fn 事件；检测不到时请选择其他修饰键。KeyDock 不会自动更改系统设置。")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Button("打开键盘设置") { model.openKeyboardSettings() }
                        }
                    }
                    section("常规") {
                        Toggle("登录时启动 KeyDock", isOn: Binding(get: { model.loginEnabled }, set: model.setLoginEnabled))
                            .toggleStyle(.switch).controlSize(.small)
                        if model.loginNeedsApproval {
                            Button("前往系统设置允许后台登录项") { SMAppService.openSystemSettingsLoginItems() }
                        }
                        HStack {
                            Text("配置文件").font(.subheadline)
                            Spacer()
                            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([model.repository.url]) }
                        }
                        if model.configurationNeedsRecovery {
                            Button("保留备份并重置配置", role: .destructive) { model.recoverConfiguration() }
                        }
                        if let message = model.errorMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                    }
                    Text("KeyDock \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · 本地运行 · 不收集或上传键盘输入")
                        .font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }.padding(24)
            }
        }.frame(width: 620, height: 570)
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }
    private func settingsRow<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            content()
        }
    }
}
