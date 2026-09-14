import XCTest
@testable import KeyDockCore

final class InteractionTests: XCTestCase {
    func testTwoCompleteQuickTapsTriggerOnce() {
        var recognizer = DoubleTapRecognizer()
        recognizer.press(at: 0)
        XCTAssertFalse(recognizer.release(at: 0.05))
        recognizer.press(at: 0.18)
        XCTAssertTrue(recognizer.release(at: 0.23))
        XCTAssertFalse(recognizer.release(at: 0.24))
    }
    func testSlowTapsAndLongHoldsDoNotTrigger() {
        var recognizer = DoubleTapRecognizer()
        recognizer.press(at: 0)
        XCTAssertFalse(recognizer.release(at: 0.1))
        recognizer.press(at: 0.6)
        XCTAssertFalse(recognizer.release(at: 0.7))
        recognizer.press(at: 0.8)
        XCTAssertFalse(recognizer.release(at: 1.3))
    }
    func testChordOrFocusResetCancelsDoubleTap() {
        var recognizer = DoubleTapRecognizer()
        recognizer.press(at: 0)
        XCTAssertFalse(recognizer.release(at: 0.05))
        recognizer.reset()
        recognizer.press(at: 0.1)
        XCTAssertFalse(recognizer.release(at: 0.15))
    }
    func testRepeatedModifierDownDoesNotTrigger() {
        var recognizer = DoubleTapRecognizer()
        recognizer.press(at: 0)
        recognizer.press(at: 0.1)
        XCTAssertFalse(recognizer.release(at: 0.2))
    }
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
        config.prefix = .function
        XCTAssertFalse(match(0, .control))
        XCTAssertTrue(match(0, .function))
    }
}
