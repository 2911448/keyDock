import Foundation

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
