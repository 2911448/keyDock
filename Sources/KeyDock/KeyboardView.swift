import SwiftUI
import KeyDockCore

private struct KeyCap: Identifiable {
    let label: String
    let code: UInt16?
    var units: CGFloat = 1
    var modifier: Modifier? = nil
    var id: String { "\(label)-\(code.map(String.init) ?? "decoration")" }
    static func character(_ code: UInt16, units: CGFloat = 1) -> Self {
        Self(label: PhysicalKeys.labels[code] ?? "", code: code, units: units)
    }
}

private let keyboardRows: [[KeyCap]] = [
    [.init(label: "esc", code: nil, units: 1.5)] + (1...12).map { .init(label: "F\($0)", code: nil) } + [.init(label: "◉", code: nil, units: 1.5)],
    [50,18,19,20,21,23,22,26,28,25,29,27,24].map { .character(UInt16($0)) } + [.init(label: "delete", code: nil, units: 2)],
    [.init(label: "tab", code: nil, units: 1.5)] + [12,13,14,15,17,16,32,34,31,35,33,30].map { .character(UInt16($0)) } + [.character(42, units: 1.5)],
    [.init(label: "caps lock", code: nil, units: 1.8)] + [0,1,2,3,5,4,38,40,37,41,39].map { .character(UInt16($0)) } + [.init(label: "return", code: nil, units: 2.2)],
    [.init(label: "shift", code: nil, units: 2.3, modifier: .shift)] + [6,7,8,9,11,45,46,43,47,44].map { .character(UInt16($0)) } + [.init(label: "shift", code: nil, units: 2.7, modifier: .shift)],
    [.init(label: "fn", code: nil, modifier: .function), .init(label: "control", code: nil, modifier: .control),
     .init(label: "option", code: nil, modifier: .option), .init(label: "command", code: nil, units: 1.4, modifier: .command),
     .init(label: "space", code: nil, units: 5.2), .init(label: "command", code: nil, units: 1.4, modifier: .command),
     .init(label: "option", code: nil, modifier: .option), .init(label: "←", code: nil),
     .init(label: "↑  ↓", code: nil), .init(label: "→", code: nil)]
]

struct KeyboardView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(spacing: 0) {
            header
            if !model.listenerActive {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("全局快捷键尚未生效：双击呼出、后台启动和快捷键隐藏暂不可用。")
                        .font(.system(size: 11))
                    Spacer()
                    Button("检查授权") { model.showSettings() }.controlSize(.small)
                }
                .padding(10).background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24).padding(.bottom, 10)
            }
            if let message = model.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    Text(message).font(.system(size: 11)).lineLimit(2)
                    Spacer(minLength: 0)
                    Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
                .padding(10).background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24).padding(.bottom, 10)
            }
            GeometryReader { geometry in
                VStack(spacing: 7) {
                    ForEach(Array(keyboardRows.enumerated()), id: \.offset) { rowIndex, row in
                        let unit = (geometry.size.width - CGFloat(row.count - 1) * 6) / 15
                        HStack(spacing: 6) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                                KeyCapView(key: key, model: model, compact: rowIndex == 0)
                                    .frame(width: unit * key.units, height: rowIndex == 0 ? 29 : 52)
                            }
                        }
                    }
                }
            }
            .frame(height: 324)
            .padding(.horizontal, 24)
            footer
        }
        .background {
            ZStack {
                VisualEffectBackground()
                LinearGradient(colors: [Color.primary.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.1), lineWidth: 1))
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .appPicker: AppPickerView(model: model, catalog: model.catalog)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 23, weight: .light)).foregroundStyle(.primary.opacity(0.75))
                .frame(width: 42, height: 42)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("KeyDock").font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(model.isEditing ? "编辑键盘" : "你的应用，触手可及")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
                Text(model.isEditing ? "点击一个键帽，为它选择 App。" : "按字母或点击启动 · 再次调用前台 App 即可隐藏")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.isEditing.toggle() } label: {
                Label(model.isEditing ? "完成" : "编辑", systemImage: model.isEditing ? "checkmark" : "slider.horizontal.3")
                    .font(.system(size: 12, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 8)
                    .background(model.isEditing ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.055), in: Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("editKeyboard")
            Button { model.showSettings() } label: {
                Image(systemName: "gearshape").font(.system(size: 15)).frame(width: 30, height: 32)
            }.buttonStyle(.plain).help("设置").accessibilityLabel("设置")
            Button { model.onHidePanel?() } label: {
                Image(systemName: "xmark").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 26, height: 32)
            }.buttonStyle(.plain).help("关闭面板 · Esc").accessibilityLabel("关闭面板")
        }
        .padding(.horizontal, 24).padding(.top, 21).padding(.bottom, 23)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isPaused ? .orange : (model.listenerActive ? .green : .orange)).frame(width: 5, height: 5)
            if !model.listenerActive {
                Button("启用全局快捷键") { model.showSettings() }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            } else { Text(model.isPaused ? "全局快捷键已暂停" : "\(model.configuration.bindings.count) 个应用已就位").foregroundStyle(.secondary) }
            Spacer()
            if model.configuration.bindings.isEmpty {
                Text("\(model.isEditing ? "从 A 开始，添加你的第一个 App" : "点击「编辑」开始配置")")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(model.configuration.prefix.symbol) + 按键").foregroundStyle(.secondary)
            }
            Spacer()
            Text("连按两次 \(model.configuration.summonKey.symbol)").foregroundStyle(.secondary)
            Text("呼出").foregroundStyle(.tertiary)
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 28).padding(.top, 10).padding(.bottom, 18)
    }
}

private struct KeyCapView: View {
    let key: KeyCap
    @ObservedObject var model: AppModel
    let compact: Bool
    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme
    private var binding: AppBinding? { key.code.flatMap { model.binding(for: $0) } }
    private var highlighted: Bool { key.modifier == model.configuration.prefix }
    private var actionable: Bool { key.code != nil && (model.isEditing || binding != nil) }
    var body: some View {
        Button {
            if let code = key.code { model.selectKey(code) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 5 : 7)
                    .fill(background)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.045), radius: 1, y: 1)
                RoundedRectangle(cornerRadius: compact ? 5 : 7)
                    .strokeBorder(highlighted ? Color.accentColor.opacity(0.35) : Color.primary.opacity(hovered && actionable ? 0.2 : 0.055), lineWidth: 1)
                if let binding {
                    VStack(spacing: 2) {
                        Image(nsImage: model.catalog.icon(at: binding.path)).resizable().interpolation(.high).frame(width: 27, height: 27)
                        Text(key.label).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    }
                    if model.isEditing && hovered {
                        Image(systemName: "pencil.circle.fill").font(.system(size: 13)).foregroundStyle(.white, Color.accentColor)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(4)
                    }
                } else if let modifier = key.modifier {
                    VStack(spacing: 3) {
                        Text(modifier == .function ? "◎" : modifier.symbol).font(.system(size: 15, weight: .regular))
                        Text(key.label).font(.system(size: 8))
                    }.foregroundStyle(highlighted ? Color.accentColor : Color.secondary.opacity(0.65))
                } else {
                    Text(model.isEditing && hovered && key.code != nil ? "+" : key.label)
                        .font(.system(size: key.code == nil ? 10 : 13, weight: .medium, design: .rounded))
                        .foregroundStyle(key.code == nil ? Color.secondary.opacity(0.5) : Color.primary.opacity(model.isEditing ? 0.65 : 0.35))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(!actionable)
        .onHover { hovered = $0 }
        .help(binding.map { "\(model.configuration.prefix.symbol)\(key.label) · \($0.name)" } ?? (key.code != nil ? "\(key.label) · \(model.isEditing ? "选择 App" : "未配置")" : key.label))
        .accessibilityLabel("\(key.label)\(binding.map { "，\($0.name)" } ?? "")")
        .accessibilityIdentifier(key.code.map { "key-\($0)" } ?? "decoration-\(key.label)")
    }
    private var background: Color {
        if highlighted { return Color.accentColor.opacity(0.08) }
        if hovered && actionable { return Color.accentColor.opacity(0.1) }
        if binding != nil { return scheme == .dark ? Color.white.opacity(0.13) : Color.white.opacity(0.8) }
        return scheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.38)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
