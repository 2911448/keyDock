import XCTest
@testable import KeyDockCore

final class InteractionTests: XCTestCase {
    func testPanelSnapshotDrivesToggleEvenWhenPanelHasFocus() {
        XCTAssertEqual(ApplicationAction.decide(isRunning: false, isHidden: false, wasFrontmost: false), .launch)
        XCTAssertEqual(ApplicationAction.decide(isRunning: true, isHidden: false, wasFrontmost: false), .activate)
        XCTAssertEqual(ApplicationAction.decide(isRunning: true, isHidden: false, wasFrontmost: true), .hide)
        XCTAssertEqual(ApplicationAction.decide(isRunning: true, isHidden: true, wasFrontmost: true), .activate)
    }
    func testOnlyConfiguredExactChordIsCapturedAndPrefixChangesImmediately() {
        var config = Configuration()
        config.bindings = [AppBinding(keyCode: 0, bundleIdentifier: "com.apple.Safari", path: "/Applications/Safari.app", name: "Safari")]
        func match(_ code: UInt16, _ modifiers: KeyModifiers, paused: Bool = false, editing: Bool = false) -> Bool {
            ShortcutRouter.matches(keyCode: code, modifiers: modifiers, configuration: config, paused: paused, editing: editing)
        }
        XCTAssertTrue(match(0, .control))
        XCTAssertFalse(match(1, .control))
        XCTAssertFalse(match(0, [.control, .shift]))
        XCTAssertFalse(match(0, .control, paused: true))
        XCTAssertFalse(match(0, .control, editing: true))
        config.prefix = .option
        XCTAssertFalse(match(0, .control))
        XCTAssertTrue(match(0, .option))
    }
}
