import XCTest
@testable import KeyDockCore

final class StoreCompatibilityTests: XCTestCase {
    func testPlainLegacyBindingLoadsAndIsBackedUpBeforeStoreFormatSave() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repository = ConfigurationRepository(url: dir.appendingPathComponent("settings.json"))
        let bytes = Data(#"{"version":2,"prefix":"option","summonKey":"control","bindings":[{"keyCode":0,"path":"/A.app","name":"A"}]}"#.utf8)
        try bytes.write(to: repository.url)
        let config = try repository.load()
        XCTAssertEqual(config.version, 4); XCTAssertEqual(config.bindings.count, 1)
        XCTAssertEqual(try Data(contentsOf: repository.url), bytes)
        try repository.save(config)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("settings.v2-backup.json")), bytes)
        XCTAssertEqual(try repository.load(), config)
    }
    func testLegacyFunctionDoesNotSilentlyBecomeAppLaunch() throws {
        let bytes = Data(#"{"version":2,"prefix":"control","summonKey":"control","bindings":[{"keyCode":0,"path":"/A.app","name":"A","function":{"kind":"menu","menuPath":["File","New"]}}]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Configuration.self, from: bytes)) { error in
            XCTAssertEqual((error as? ConfigurationError), .unsupportedAction)
        }
    }
    func testUnsupportedModifiersCannotBeSavedAndBookmarkRoundTrips() throws {
        var c = Configuration(); c.prefix = .function
        XCTAssertThrowsError(try c.validated())
        c.prefix = .option; c.summonKey = .shift
        XCTAssertThrowsError(try c.validated())
        c.summonKey = .option
        c.bindings = [AppBinding(keyCode: 0, bundleIdentifier: nil, path: "/A.app", name: "A", bookmark: Data([1,2,3]))]
        let bytes = try JSONEncoder().encode(c.validated())
        XCTAssertEqual(try JSONDecoder().decode(Configuration.self, from: bytes), c)
    }
}
