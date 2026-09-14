import AppKit
import ApplicationServices
import KeyDockCore

final class KeyboardMonitor {
    var onRecordKeyDown: ((UInt16, KeyModifiers) -> Void)?
    var onKeyDown: ((UInt16, KeyModifiers, Bool) -> Bool)?
    var onSummon: (() -> Void)?
    var onStatus: ((Bool, String) -> Void)?
    var onGlobe: (() -> Void)?
    var onEventCount: ((Int) -> Void)?
    var summonKey: Modifier = .control { didSet { resetGesture() } }
    var gesturesEnabled = true { didSet { if !gesturesEnabled { resetGesture() } } }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var localMonitor: Any?
    private var timer: Timer?
    private var recognizer = DoubleTapRecognizer()
    private var pressedModifiers = Set<UInt16>()
    private var capturedKeys = Set<UInt16>()
    private var localCapturedKeys = Set<UInt16>()
    private var observers: [NSObjectProtocol] = []
    private var wasTrusted = false
    private var lastStatus = ""
    private var eventCount = 0
    private let accessibilityTrusted: () -> Bool
    private let createTap: (CGEventTapCallBack, UnsafeMutableRawPointer) -> CFMachPort?

    init(accessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
         createTap: @escaping (CGEventTapCallBack, UnsafeMutableRawPointer) -> CFMachPort? = KeyboardMonitor.makeTap) {
        self.accessibilityTrusted = accessibilityTrusted
        self.createTap = createTap
    }

    private static func makeTap(callback: CGEventTapCallBack, context: UnsafeMutableRawPointer) -> CFMachPort? {
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        return CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                 eventsOfInterest: mask, callback: callback, userInfo: context)
    }

    func start() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == FunctionExecutor.eventTag { return event }
            if event.type == .keyUp {
                return self.localCapturedKeys.remove(event.keyCode) != nil ? nil : event
            }
            if self.localCapturedKeys.contains(event.keyCode) {
                if event.isARepeat { return nil }
                // Launching another app can send the previous key-up to its window instead.
                self.localCapturedKeys.remove(event.keyCode)
            }
            if let recorder = self.onRecordKeyDown {
                if !event.isARepeat { recorder(event.keyCode, Self.modifiers(event.modifierFlags)) }
                self.localCapturedKeys.insert(event.keyCode)
                return nil
            }
            let handled = self.onKeyDown?(event.keyCode, Self.modifiers(event.modifierFlags), event.isARepeat) ?? false
            if handled { self.localCapturedKeys.insert(event.keyCode) }
            return handled ? nil : event
        }
        refresh()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                            object: nil, queue: .main) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier == ProcessInfo.processInfo.processIdentifier { self?.refresh() }
        })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.resetGesture(); self?.capturedKeys.removeAll(); self?.localCapturedKeys.removeAll(); self?.refresh()
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.resetGesture() })
        }
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func resetGesture() { recognizer.reset(); pressedModifiers.removeAll() }

    private func report(_ active: Bool, _ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatus?(active, status)
    }

    func retry() {
        tearDownTap()
        resetGesture()
        capturedKeys.removeAll()
        localCapturedKeys.removeAll()
        refresh()
    }

    func refresh() {
        onEventCount?(eventCount)
        let trusted = accessibilityTrusted()
        if wasTrusted && !trusted {
            // Drop an old tap on revocation. macOS independently authorizes every new tap.
            tearDownTap()
            resetGesture()
        }
        wasTrusted = trusted
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                resetGesture()
            }
            let enabled = CGEvent.tapIsEnabled(tap: tap)
            report(enabled, enabled ? "快捷键监听正常" : "监听暂停，请检查系统权限")
            return
        }
        // AXIsProcessTrusted is a snapshot, not proof that a CG event tap cannot be created.
        // Attempt the actual capability; a denied tap returns nil without bypassing macOS permissions.
        guard let newTap = createTap({ _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue().receive(type: type, event: event)
        }, Unmanaged.passUnretained(self).toOpaque()) else {
            report(false, trusted ? "系统已授权，但全局监听创建失败" : "当前版本的辅助功能授权未生效")
            return
        }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: newTap, enable: true)
        let enabled = CGEvent.tapIsEnabled(tap: newTap)
        report(enabled, enabled ? "快捷键监听正常" : "监听尚未启用")
    }

    // Internal so tests can exercise the real filter using unposted events, without system permissions.
    func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resetGesture()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == FunctionExecutor.eventTag { return Unmanaged.passUnretained(event) }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        eventCount += 1
        let modifiers = Self.modifiers(NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)))
        let time = Double(event.timestamp) / 1_000_000_000
        if type == .flagsChanged {
            if code == 63 { onGlobe?() }
            if gesturesEnabled, let modifier = Modifier.forKeyCode(code) {
                let isRelease = pressedModifiers.contains(code) || !modifiers.contains(modifier.mask)
                if isRelease { pressedModifiers.remove(code) } else { pressedModifiers.insert(code) }
                if modifier != summonKey || !modifiers.subtracting(summonKey.mask).isEmpty || pressedModifiers.count > 1 {
                    recognizer.reset()
                } else if isRelease {
                    if recognizer.release(at: time) { onSummon?() }
                } else {
                    recognizer.press(at: time)
                }
            } else { recognizer.reset() }
        } else if type == .keyDown {
            recognizer.reset()
            let repeated = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if capturedKeys.contains(code) {
                if repeated { return nil }
                // A fresh down is a new press, even if sleep/secure input dropped its earlier up.
                capturedKeys.remove(code)
            }
            if let recorder = onRecordKeyDown {
                capturedKeys.insert(code)
                if !repeated { recorder(code, modifiers) }
                return nil
            }
            if onKeyDown?(code, modifiers, repeated) == true { capturedKeys.insert(code); return nil }
        } else if type == .keyUp {
            if capturedKeys.remove(code) != nil { return nil }
        }
        return Unmanaged.passUnretained(event)
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

    private func tearDownTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil; tap = nil
    }

    deinit {
        timer?.invalidate()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        tearDownTap()
    }
}
