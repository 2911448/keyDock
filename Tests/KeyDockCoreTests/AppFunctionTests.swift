import XCTest
@testable import KeyDockCore

final class AppFunctionTests: XCTestCase {
    func testVersionOneBindingsRemainApplicationTogglesAndOriginalIsBackedUp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ConfigurationRepository(url: root.appendingPathComponent("settings.json"))
        let original = Data(#"{"version":1,"prefix":"control","summonKey":"option","bindings":[{"keyCode":2,"bundleIdentifier":"com.tencent.xinWeChat","path":"/Applications/WeChat.app","name":"WeChat"}]}"#.utf8)
        try original.write(to: repository.url)
        let migrated = try repository.load()
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.summonKey, .option)
        XCTAssertNil(migrated.bindings[0].function)
        XCTAssertEqual(migrated.bindings[0].keyCode, 2)
        XCTAssertEqual(try Data(contentsOf: repository.url), original, "Loading must not modify the user's file")
        try repository.save(migrated)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("settings.v1-backup.json")), original)
        XCTAssertEqual(try repository.load(), migrated)
    }

    func testMixedBindingsRoundTripAndFunctionCanBeReplacedWithApp() throws {
        var configuration = Configuration()
        let screenshot = AppFunction(kind: .shortcut, name: "截图", shortcut: RecordedShortcut(keyCode: 0, modifiers: 10), activateFirst: false)
        configuration.bindings = [
            AppBinding(keyCode: 2, bundleIdentifier: "wechat", path: "/WeChat.app", name: "微信"),
            AppBinding(keyCode: 7, bundleIdentifier: "wechat", path: "/WeChat.app", name: "微信", function: screenshot),
            AppBinding(keyCode: 3, bundleIdentifier: "test", path: "/Test.app", name: "测试", function: AppFunction(kind: .menu, name: "新建", menuPath: ["文件", "新建"]))
        ]
        let restored = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration)).validated()
        XCTAssertEqual(configuration, restored)
        XCTAssertFalse(restored.bindings[1].function!.activateFirst)
        configuration.bindings[1].function = nil
        XCTAssertNil(try configuration.validated().bindings[1].function)
        XCTAssertEqual(configuration.bindings[0].displayName, "微信")
    }

    func testRejectMalformedActionsAndUnsupportedShortcuts() throws {
        XCTAssertFalse(RecordedShortcut(keyCode: 0, modifiers: 0).isValid)
        XCTAssertFalse(RecordedShortcut(keyCode: 0, modifiers: 8).isValid)
        XCTAssertFalse(RecordedShortcut(keyCode: 55, modifiers: 2).isValid)
        XCTAssertFalse(RecordedShortcut(keyCode: 0, modifiers: 16).isValid)
        XCTAssertTrue(RecordedShortcut(keyCode: 122, modifiers: 0).isValid)
        XCTAssertEqual(RecordedShortcut(keyCode: 0, modifiers: 10).label, "⇧⌘A")
        var configuration = Configuration()
        configuration.bindings = [AppBinding(keyCode: 7, bundleIdentifier: nil, path: "/A.app", name: "A", function: AppFunction(kind: .menu, name: "bad", menuPath: ["bad"]))]
        XCTAssertThrowsError(try configuration.validated())
    }
}
