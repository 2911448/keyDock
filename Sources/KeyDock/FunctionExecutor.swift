import AppKit
import ApplicationServices
import KeyDockCore

@MainActor
final class FunctionExecutor {
    // Every generated event carries this tag, including key-up and modifier events.
    nonisolated static let eventTag: Int64 = 0x4B444F434B414354
    private(set) var busy = false

    func execute(_ function: AppFunction, at url: URL, triggerKey: UInt16) async throws -> String {
        guard !busy else { throw FunctionError.busy }
        guard function.isValid else { throw FunctionError.unavailable("功能配置无效，请重新绑定。") }
        guard AXIsProcessTrusted() else { throw FunctionError.permission }
        busy = true
        defer { busy = false }
        try await waitForRelease(triggerKey)
        let activate = function.kind == .menu || function.activateFirst
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.resolvingSymlinksInPath() == url.resolvingSymlinksInPath() && !$0.isTerminated
        }
        let app: NSRunningApplication
        if let running { app = running }
        else {
            let options = NSWorkspace.OpenConfiguration()
            options.activates = activate
            app = try await NSWorkspace.shared.openApplication(at: url, configuration: options)
        }
        for _ in 0..<50 {
            if app.isFinishedLaunching { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard !app.isTerminated, app.isFinishedLaunching else { throw FunctionError.unavailable("应用尚未准备就绪，请稍后重试。") }
        if activate {
            app.activate(options: [])
            for _ in 0..<30 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { throw FunctionError.focus }
        }
        // Allow panel dismissal / app launch to settle before screenshot or other actions.
        try await Task.sleep(nanoseconds: running == nil ? 500_000_000 : 180_000_000)
        try await waitForRelease(triggerKey)
        switch function.kind {
        case .menu:
            try await MenuFunctions.perform(pid: app.processIdentifier, path: function.menuPath)
            return "已执行菜单：\(function.name)"
        case .shortcut:
            guard let shortcut = function.shortcut else { throw FunctionError.unavailable("请重新录入快捷键。") }
            if activate, NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier { throw FunctionError.focus }
            try Self.post(shortcut)
            return "已发送快捷键：\(function.name)（\(shortcut.label)）"
        }
    }

    private func waitForRelease(_ key: UInt16) async throws {
        for _ in 0..<100 {
            let held = [key, 54, 55, 56, 60, 58, 61, 59, 62, 63].contains {
                CGEventSource.keyState(.hidSystemState, key: CGKeyCode($0))
            }
            if !held && !CGEventSource.buttonState(.hidSystemState, button: .left) { return }
            try await Task.sleep(nanoseconds: 30_000_000)
        }
        throw FunctionError.releaseKeys
    }

    /// Construct before posting so allocation failure cannot leave a modifier stuck down.
    nonisolated static func events(for shortcut: RecordedShortcut) -> [CGEvent]? {
        guard shortcut.isValid, let source = CGEventSource(stateID: .privateState) else { return nil }
        source.userData = eventTag
        let pairs: [(KeyModifiers, CGKeyCode, CGEventFlags)] = [(.control, 59, .maskControl), (.option, 58, .maskAlternate), (.shift, 56, .maskShift), (.command, 55, .maskCommand)]
        let modifiers = pairs.filter { KeyModifiers(rawValue: shortcut.modifiers).contains($0.0) }
        var flags: CGEventFlags = []
        var events: [CGEvent] = []
        func append(_ code: CGKeyCode, _ down: Bool) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return false }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            events.append(event)
            return true
        }
        for (_, code, flag) in modifiers { flags.insert(flag); guard append(code, true) else { return nil } }
        guard append(shortcut.keyCode, true), append(shortcut.keyCode, false) else { return nil }
        for (_, code, flag) in modifiers.reversed() { flags.remove(flag); guard append(code, false) else { return nil } }
        return events
    }

    private static func post(_ shortcut: RecordedShortcut) throws {
        guard let events = events(for: shortcut) else { throw FunctionError.unavailable("无法生成快捷键事件。") }
        for event in events { event.post(tap: .cghidEventTap) }
    }
}
