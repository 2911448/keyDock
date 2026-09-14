import XCTest
@testable import KeyDockCore

final class ConfigurationTests: XCTestCase {
    private var directory: URL!
    private var repository: ConfigurationRepository!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repository = ConfigurationRepository(url: directory.appendingPathComponent("settings.json"))
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    func testFreshInstallAndRoundTripEdits() throws {
        XCTAssertEqual(try repository.load(), Configuration())
        var config = Configuration()
        config.prefix = .option
        config.summonKey = .function
        config.bindings = [AppBinding(keyCode: 0, bundleIdentifier: "com.apple.Safari", path: "/Applications/Safari.app", name: "Safari")]
        try repository.save(config)
        XCTAssertEqual(try repository.load(), config)
        config.bindings[0].name = "另一个应用"
        try repository.save(config)
        XCTAssertEqual(try repository.load().bindings[0].name, "另一个应用")
        config.bindings.removeAll()
        try repository.save(config)
        XCTAssertTrue(try repository.load().bindings.isEmpty)
    }
    func testCorruptOriginalPreservedUntilExplicitBackupReset() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let invalid = Data("broken config".utf8)
        try invalid.write(to: repository.url)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.url), invalid)
        let backup = try repository.backupAndReset()
        XCTAssertEqual(try Data(contentsOf: backup), invalid)
        XCTAssertEqual(try repository.load(), Configuration())
    }
    func testRejectDuplicateKeysAndUnsupportedVersion() throws {
        var config = Configuration()
        let binding = AppBinding(keyCode: 0, bundleIdentifier: nil, path: "/A.app", name: "A")
        config.bindings = [binding, binding]
        XCTAssertThrowsError(try repository.save(config))
        config.bindings = []
        config.version = 2
        XCTAssertThrowsError(try repository.save(config))
    }
}
