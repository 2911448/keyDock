import AppKit
import ApplicationServices
import KeyDockCore

struct DiscoveredMenuFunction: Identifiable {
    let path: [String]
    let shortcutLabel: String
    let enabled: Bool
    var id: String { path.joined(separator: "\u{1F}") }
    var name: String { path.last ?? "" }
    var breadcrumb: String { path.joined(separator: " → ") }
    var function: AppFunction { AppFunction(kind: .menu, name: name, menuPath: path) }
}

struct MenuScan {
    let functions: [DiscoveredMenuFunction]
    let partial: Bool
}

enum FunctionError: LocalizedError {
    case permission, unavailable(String), releaseKeys, focus, ambiguous, disabled, menuMissing, busy
    var errorDescription: String? {
        switch self {
        case .permission: return "需要辅助功能权限才能读取菜单或执行应用功能，请在设置中开启后重试。"
        case .unavailable(let message): return message
        case .releaseKeys: return "按键尚未松开，已取消执行。请松开所有修饰键后重试。"
        case .focus: return "目标应用未获得焦点，已取消执行，避免快捷键发送到其他应用。"
        case .ambiguous: return "存在同名菜单路径，无法可靠区分，请改用手动快捷键。"
        case .disabled: return "该菜单功能当前不可用，请先在目标应用中打开合适的窗口或选择内容。"
        case .menuMissing: return "找不到已绑定的菜单功能。应用语言或菜单可能已变化，请重新读取并绑定。"
        case .busy: return "已有应用功能正在执行，请稍后重试。"
        }
    }
}

/// AX messaging is synchronous. Keep it off the main thread and bound each traversal.
final class MenuFunctions {
    private static let queue = DispatchQueue(label: "io.keydock.menu-functions", qos: .userInitiated)

    static func scan(pid: pid_t) async throws -> MenuScan {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try collect(pid: pid)
                    // Duplicate paths cannot be safely persisted; exclude them rather than choosing arbitrarily.
                    let grouped = Dictionary(grouping: result.items, by: { $0.0.path })
                    let functions = result.items.filter { grouped[$0.0.path]?.count == 1 }.map { $0.0 }
                    continuation.resume(returning: MenuScan(functions: functions, partial: result.partial))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func perform(pid: pid_t, path: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw FunctionError.focus }
                    let result = try collect(pid: pid)
                    guard !result.partial else { throw FunctionError.unavailable("菜单读取不完整，已取消执行。请稍后重试。") }
                    let matches = result.items.filter { $0.0.path == path }
                    guard !matches.isEmpty else { throw FunctionError.menuMissing }
                    guard matches.count == 1 else { throw FunctionError.ambiguous }
                    let (item, element) = matches[0]
                    guard item.enabled, value(element, kAXEnabledAttribute) as? Bool != false else { throw FunctionError.disabled }
                    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { throw FunctionError.focus }
                    guard AXUIElementPerformAction(element, kAXPressAction as CFString) == .success else {
                        throw FunctionError.unavailable("应用未接受菜单操作，请检查当前窗口状态后重试。")
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func collect(pid: pid_t) throws -> (items: [(DiscoveredMenuFunction, AXUIElement)], partial: Bool) {
        guard AXIsProcessTrusted() else { throw FunctionError.permission }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let rawBar = value(app, kAXMenuBarAttribute), CFGetTypeID(rawBar) == AXUIElementGetTypeID() else {
            throw FunctionError.unavailable("应用暂未暴露菜单。请先打开应用的主窗口，再返回刷新；也可手动添加快捷键。")
        }
        let bar = unsafeBitCast(rawBar, to: AXUIElement.self)
        var items: [(DiscoveredMenuFunction, AXUIElement)] = []
        var visited = 0
        var partial = false
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        func walk(_ element: AXUIElement, path: [String], depth: Int) {
            guard depth < 24, visited < 1800, ProcessInfo.processInfo.systemUptime < deadline else { partial = true; return }
            visited += 1
            let role = value(element, kAXRoleAttribute) as? String ?? ""
            let title = value(element, kAXTitleAttribute) as? String ?? ""
            let named = (role == kAXMenuBarItemRole || role == kAXMenuItemRole) && !title.isEmpty
            // The Apple menu is system-wide, not a function of the selected application.
            if path.isEmpty && (title == "Apple" || title == "苹果" || title == "") { return }
            let nextPath = named ? path + [title] : path
            let children = value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
            if role == kAXMenuItemRole, named, children.isEmpty, nextPath.count >= 2 {
                var actions: CFArray?
                if AXUIElementCopyActionNames(element, &actions) == .success,
                   (actions as? [String] ?? []).contains(kAXPressAction) {
                    let character = value(element, kAXMenuItemCmdCharAttribute) as? String ?? ""
                    let bits = (value(element, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0
                    // AX menu masks: shift=1, option=2, control=4, noCommand=8.
                    let prefix = (bits & 4 != 0 ? "⌃" : "") + (bits & 2 != 0 ? "⌥" : "")
                        + (bits & 1 != 0 ? "⇧" : "") + (bits & 8 == 0 ? "⌘" : "")
                    let virtualKey = (value(element, kAXMenuItemCmdVirtualKeyAttribute) as? NSNumber)?.uint16Value
                    let keyLabel = character.isEmpty ? (virtualKey.flatMap { RecordedShortcut.specialLabels[$0] } ?? "") : character.uppercased()
                    let label = keyLabel.isEmpty ? "" : prefix + keyLabel
                    items.append((DiscoveredMenuFunction(path: nextPath, shortcutLabel: label,
                                                          enabled: value(element, kAXEnabledAttribute) as? Bool ?? true), element))
                }
            }
            for child in children { walk(child, path: nextPath, depth: depth + 1) }
        }
        walk(bar, path: [], depth: 0)
        return (items, partial)
    }
}
