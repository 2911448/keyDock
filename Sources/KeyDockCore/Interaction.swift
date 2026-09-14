import Foundation

/// Recognizes two complete, isolated taps. Chords and long holds cannot summon the panel.
public struct DoubleTapRecognizer {
    public let interval: TimeInterval
    private var downAt: TimeInterval?
    private var firstRelease: TimeInterval?
    public init(interval: TimeInterval = 0.350) { self.interval = interval }
    public mutating func reset() { downAt = nil; firstRelease = nil }
    public mutating func press(at time: TimeInterval) {
        guard downAt == nil else { reset(); return }
        if let firstRelease, time - firstRelease > interval { self.firstRelease = nil }
        downAt = time
    }
    public mutating func release(at time: TimeInterval) -> Bool {
        guard let down = downAt, time >= down, time - down <= interval else { reset(); return false }
        downAt = nil
        if let first = firstRelease, down >= first, time - first <= interval {
            reset()
            return true
        }
        firstRelease = time
        return false
    }
}

public enum ApplicationAction: Equatable {
    case launch, activate, hide
    public static func decide(isRunning: Bool, isHidden: Bool, wasFrontmost: Bool) -> Self {
        guard isRunning else { return .launch }
        return wasFrontmost && !isHidden ? .hide : .activate
    }
}

public enum ShortcutRouter {
    public static func matches(keyCode: UInt16, modifiers: KeyModifiers, configuration: Configuration,
                               paused: Bool, editing: Bool) -> Bool {
        !paused && !editing && modifiers == configuration.prefix.mask && configuration.bindings.contains { $0.keyCode == keyCode }
    }
}
