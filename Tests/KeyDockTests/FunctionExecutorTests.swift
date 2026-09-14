import XCTest
import AppKit
import KeyDockCore
@testable import KeyDock

final class FunctionExecutorTests: XCTestCase {
    func testGeneratedShortcutBalancesModifiersAndBypassesLauncher() throws {
        let shortcut = RecordedShortcut(keyCode: 0, modifiers: KeyModifiers.command.union(.shift).rawValue)
        let events = try XCTUnwrap(FunctionExecutor.events(for: shortcut))
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [56, 55, 0, 0, 55, 56])
        XCTAssertTrue(events[2].flags.contains([.maskShift, .maskCommand]))
        XCTAssertEqual(events.last?.flags, [])
        let monitor = KeyboardMonitor(accessibilityTrusted: { false }, createTap: { _, _ in nil })
        var dispatched = 0
        monitor.onKeyDown = { _, _, _ in dispatched += 1; return true }
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), FunctionExecutor.eventTag)
            XCTAssertNotNil(monitor.receive(type: event.type, event: event))
        }
        XCTAssertEqual(dispatched, 0, "Our generated events must never retrigger bindings")
        let physical = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        XCTAssertNil(monitor.receive(type: .keyDown, event: physical))
        XCTAssertEqual(dispatched, 1, "Real events must still reach the launcher")
    }

    func testRecordingInterceptsChordAndMatchingReleaseBeforeOtherApps() throws {
        let monitor = KeyboardMonitor(accessibilityTrusted: { false }, createTap: { _, _ in nil })
        var recorded: [UInt16] = []
        var launched = false
        monitor.onRecordKeyDown = { code, _ in recorded.append(code) }
        monitor.onKeyDown = { _, _, _ in launched = true; return false }
        let down = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        let up = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false))
        XCTAssertNil(monitor.receive(type: .keyDown, event: down))
        down.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        XCTAssertNil(monitor.receive(type: .keyDown, event: down))
        monitor.onRecordKeyDown = nil
        XCTAssertNil(monitor.receive(type: .keyUp, event: up))
        XCTAssertEqual(recorded, [0])
        XCTAssertFalse(launched)
    }

    func testInvalidShortcutGeneratesNoPartialSequence() {
        XCTAssertNil(FunctionExecutor.events(for: RecordedShortcut(keyCode: 55, modifiers: 2)))
        XCTAssertNil(FunctionExecutor.events(for: RecordedShortcut(keyCode: 0, modifiers: 0)))
    }
}
