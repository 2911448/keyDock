import Foundation

public struct RecordedShortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: Int
    public init(keyCode: UInt16, modifiers: Int) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let specialLabels: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]
    public var isValid: Bool {
        let known = PhysicalKeys.labels[keyCode] != nil || Self.specialLabels[keyCode] != nil
        // Fn is hardware dependent; record ordinary modifiers or a standalone function key.
        let functionKey = Self.specialLabels[keyCode]?.hasPrefix("F") == true
        return known && modifiers >= 0 && modifiers & ~15 == 0 && (modifiers & 7 != 0 || functionKey)
    }
    public var label: String {
        let flags = KeyModifiers(rawValue: modifiers)
        return [Modifier.control, .option, .shift, .command].filter { flags.contains($0.mask) }
            .map(\.symbol).joined() + (PhysicalKeys.labels[keyCode] ?? Self.specialLabels[keyCode] ?? "?")
    }
}

public struct AppFunction: Codable, Equatable {
    public enum Kind: String, Codable { case menu, shortcut }
    public var kind: Kind
    public var name: String
    public var menuPath: [String]
    public var shortcut: RecordedShortcut?
    public var activateFirst: Bool
    public init(kind: Kind, name: String, menuPath: [String] = [], shortcut: RecordedShortcut? = nil, activateFirst: Bool = true) {
        self.kind = kind; self.name = name; self.menuPath = menuPath
        self.shortcut = shortcut; self.activateFirst = activateFirst
    }
    public var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .menu: return menuPath.count >= 2 && menuPath.count <= 12 && menuPath.allSatisfy { !$0.isEmpty }
        case .shortcut: return shortcut?.isValid == true
        }
    }
}
