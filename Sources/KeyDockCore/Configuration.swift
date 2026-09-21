import Foundation

public enum Modifier: String, Codable, CaseIterable, Identifiable {
    case control, command, option, shift, function
    public static let storeChoices: [Modifier] = [.control, .option, .command]
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .control: return "Control"
        case .command: return "Command"
        case .option: return "Option"
        case .shift: return "Shift"
        case .function: return "Fn / 地球键"
        }
    }
    public var symbol: String {
        switch self {
        case .control: return "⌃"
        case .command: return "⌘"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .function: return "🌐"
        }
    }
    public var mask: KeyModifiers {
        switch self {
        case .control: return .control
        case .command: return .command
        case .option: return .option
        case .shift: return .shift
        case .function: return .function
        }
    }
    public static func forKeyCode(_ code: UInt16) -> Modifier? {
        switch code {
        case 59, 62: return .control
        case 55, 54: return .command
        case 58, 61: return .option
        case 56, 60: return .shift
        case 63: return .function
        default: return nil
        }
    }
}

public struct KeyModifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1 << 0)
    public static let command = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
    public static let function = Self(rawValue: 1 << 4)
}

public enum PhysicalKeys {
    public static let labels: [UInt16: String] = [
        50:"`", 18:"1", 19:"2", 20:"3", 21:"4", 23:"5", 22:"6", 26:"7", 28:"8", 25:"9", 29:"0", 27:"-", 24:"=",
        12:"Q", 13:"W", 14:"E", 15:"R", 17:"T", 16:"Y", 32:"U", 34:"I", 31:"O", 35:"P", 33:"[", 30:"]", 42:"\\",
        0:"A", 1:"S", 2:"D", 3:"F", 5:"G", 4:"H", 38:"J", 40:"K", 37:"L", 41:";", 39:"'",
        6:"Z", 7:"X", 8:"C", 9:"V", 11:"B", 45:"N", 46:"M", 43:",", 47:".", 44:"/"
    ]
}

public struct AppBinding: Codable, Equatable, Identifiable {
    public var keyCode: UInt16
    public var bundleIdentifier: String?
    public var path: String
    public var name: String
    public var bookmark: Data?
    public var displayName: String { name }
    public var id: UInt16 { keyCode }
    public init(keyCode: UInt16, bundleIdentifier: String?, path: String, name: String, bookmark: Data? = nil) {
        self.keyCode = keyCode; self.bundleIdentifier = bundleIdentifier; self.path = path; self.name = name; self.bookmark = bookmark
    }
    private enum CodingKeys: String, CodingKey { case keyCode, bundleIdentifier, path, name, bookmark }
    private enum LegacyKeys: String, CodingKey { case function, builtInAction }
    public init(from decoder: Decoder) throws {
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        for key in [LegacyKeys.function, .builtInAction] {
            if legacy.contains(key), try !legacy.decodeNil(forKey: key) { throw ConfigurationError.unsupportedAction }
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try values.decode(UInt16.self, forKey: .keyCode)
        bundleIdentifier = try values.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        path = try values.decode(String.self, forKey: .path)
        name = try values.decode(String.self, forKey: .name)
        bookmark = try values.decodeIfPresent(Data.self, forKey: .bookmark)
    }

}

public struct Configuration: Codable, Equatable {
    public var version: Int = 4
    public var prefix: Modifier = .control
    public var summonKey: Modifier = .option
    public var bindings: [AppBinding] = []
    public init() {}
    public func validated() throws -> Self {
        guard version == 1 || version == 2 || version == 4 else { throw ConfigurationError.unsupportedVersion }
        guard Set(bindings.map(\.keyCode)).count == bindings.count,
              bindings.allSatisfy({ PhysicalKeys.labels[$0.keyCode] != nil && $0.path.hasPrefix("/") && !$0.name.isEmpty })
        else { throw ConfigurationError.invalidBindings }
        var migrated = self
        guard Modifier.storeChoices.contains(prefix), Modifier.storeChoices.contains(summonKey) else { throw ConfigurationError.unsupportedModifier }
        migrated.version = 4
        return migrated
    }
}

public enum ConfigurationError: LocalizedError, Equatable {
    case unsupportedVersion, invalidBindings, unsupportedAction, unsupportedModifier
    public var errorDescription: String? {
        switch self {
        case .unsupportedAction: return "商店版不支持应用功能或内置动作绑定，原文件已保留。"
        case .unsupportedModifier: return "商店版前缀和呼出键仅支持 Control、Option、Command。"
        case .unsupportedVersion: return "配置版本不受支持。"
        case .invalidBindings: return "配置包含重复按键或无效的应用绑定。"
        }
    }
}

public final class ConfigurationRepository {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: url.path) else { return Configuration() }
        return try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url)).validated()
    }
    public func save(_ configuration: Configuration) throws {
        let validated = try configuration.validated()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path),
           let original = try? Data(contentsOf: url),
           let previous = try? JSONDecoder().decode(Configuration.self, from: original), previous.version < validated.version {
            let backup = url.deletingPathExtension().appendingPathExtension("v\(previous.version)-backup.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try original.write(to: backup, options: .atomic) }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(validated).write(to: url, options: .atomic)
    }
    /// Preserve the original bytes before allowing a new configuration to replace them.
    public func backupAndReset() throws -> URL {
        let backup = url.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: backup)
        try save(Configuration())
        return backup
    }
}
