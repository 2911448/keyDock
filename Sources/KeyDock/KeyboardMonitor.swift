import AppKit
import Carbon
import KeyDockCore

protocol HotKeyRegistrar: AnyObject {
    func start(_ receive: @escaping (UInt32, Bool) -> Void) -> OSStatus
    func register(id: UInt32, key: UInt16, modifier: Modifier) -> OSStatus
    func unregisterAll()
}

/// Registers only configured chords; never intercepts or injects keyboard events.
final class NativeHotKeyRegistrar: HotKeyRegistrar {
    private static let signature: OSType = 0x4B444F43
    private var handler: EventHandlerRef?
    private var references: [EventHotKeyRef] = []
    private var receive: ((UInt32, Bool) -> Void)?

    func start(_ receive: @escaping (UInt32, Bool) -> Void) -> OSStatus {
        self.receive = receive
        guard handler == nil else { return noErr }
        let kinds = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        return InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                    nil, MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                  key.signature == NativeHotKeyRegistrar.signature else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<NativeHotKeyRegistrar>.fromOpaque(context).takeUnretainedValue()
            owner.receive?(key.id, GetEventKind(event) == UInt32(kEventHotKeyPressed))
            return noErr
        }, kinds.count, kinds, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(id: UInt32, key: UInt16, modifier: Modifier) -> OSStatus {
        let flags: UInt32
        switch modifier {
        case .control: flags = UInt32(controlKey)
        case .option: flags = UInt32(optionKey)
        case .command: flags = UInt32(cmdKey)
        default: return OSStatus(paramErr)
        }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(key), flags, EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference { references.append(reference) }
        return status
    }
    func unregisterAll() {
        references.forEach { UnregisterEventHotKey($0) }
        references.removeAll()
    }
    deinit {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
    }
}

final class KeyboardMonitor {
    var onKeyDown: ((UInt16, KeyModifiers, Bool) -> Bool)?
    var onSummon: (() -> Void)?
    var onStatus: ((Bool, String) -> Void)?
    var onEventCount: ((Int) -> Void)?
    var gesturesEnabled = true { didSet { if oldValue != gesturesEnabled { rebuild() } } }
    private var configuration = Configuration()
    private let registrar: HotKeyRegistrar
    private var started = false
    private var registered = Set<UInt32>()
    private var held = Set<UInt32>()
    private var localCapturedKeys = Set<UInt16>()
    private var localMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var eventCount = 0
    private var lastRegistration = "尚未注册"
    private var status: (Bool, String) = (false, "正在注册快捷键…")
    init(registrar: HotKeyRegistrar = NativeHotKeyRegistrar()) { self.registrar = registrar }

    func configure(_ configuration: Configuration) {
        guard self.configuration != configuration else { return }
        self.configuration = configuration
        rebuild()
    }
    func start() {
        guard !started else { return }
        let result = registrar.start { [weak self] id, down in self?.receive(id: id, down: down) }
        guard result == noErr else { report(false, "无法安装系统热键处理器（\(result)）"); return }
        started = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyUp { return self.localCapturedKeys.remove(event.keyCode) != nil ? nil : event }
            if event.isARepeat, self.localCapturedKeys.contains(event.keyCode) { return nil }
            self.localCapturedKeys.remove(event.keyCode)
            let handled = self.onKeyDown?(event.keyCode, Self.modifiers(event.modifierFlags), event.isARepeat) ?? false
            if handled { self.localCapturedKeys.insert(event.keyCode) }
            return handled ? nil : event
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.rebuild() })
        }
        rebuild()
    }
    func refresh() { onStatus?(status.0, status.1) }
    func retry() { if started { rebuild() } else { start() } }
    private func report(_ active: Bool, _ message: String) {
        status = (active, message)
        onStatus?(active, message)
    }
    private func rebuild() {
        guard started else { return }
        registrar.unregisterAll()
        registered.removeAll()
        held.removeAll()
        localCapturedKeys.removeAll()
        guard gesturesEnabled else { report(false, "快捷键暂时释放。上次注册结果：" + lastRegistration); return }
        var failures: [String] = []
        func register(_ id: UInt32, _ key: UInt16, _ modifier: Modifier, _ label: String) {
            let result = registrar.register(id: id, key: key, modifier: modifier)
            if result == noErr { registered.insert(id) }
            else { failures.append("\(modifier.symbol)\(label)（\(result)）") }
        }
        register(0, 49, configuration.summonKey, "空格")
        for binding in configuration.bindings {
            register(UInt32(binding.keyCode) + 1, binding.keyCode, configuration.prefix, PhysicalKeys.labels[binding.keyCode] ?? "?")
        }
        lastRegistration = failures.isEmpty ? "已注册 \(registered.count) 个全局快捷键，无需辅助功能权限"
            : "无法注册：" + failures.joined(separator: "、") + "。请更换组合或释放冲突。"
        report(failures.isEmpty, lastRegistration)
    }
    // Native callbacks and injected tests share this dispatch path.
    func receive(id: UInt32, down: Bool) {
        guard gesturesEnabled, registered.contains(id) else { return }
        if !down { held.remove(id); return }
        guard held.insert(id).inserted else { return }
        eventCount += 1
        onEventCount?(eventCount)
        if id == 0 { onSummon?() }
        else { _ = onKeyDown?(UInt16(id - 1), configuration.prefix.mask, false) }
    }
    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.function) { result.insert(.function) }
        return result
    }
    deinit {
        registrar.unregisterAll()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
}
