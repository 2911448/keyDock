import XCTest
import CoreGraphics
import KeyDockCore
@testable import KeyDock

/// Construct events but never post them to the system or install an event tap.
final class KeyboardMonitorTests: XCTestCase {
    func testAXSnapshotFalseStillAttemptsActualEventTapAndReportsFailureHonestly() {
        var attempts = 0
        var active = true
        let monitor = KeyboardMonitor(accessibilityTrusted: { false }, createTap: { _, _ in attempts += 1; return nil })
        monitor.onStatus = { enabled, _ in active = enabled }
        monitor.refresh()
        XCTAssertEqual(attempts, 1)
        XCTAssertFalse(active)
        monitor.retry()
        XCTAssertEqual(attempts, 2)
        XCTAssertFalse(active)
    }

    func testAuthorizationSnapshotTrueDoesNotMeanTapSucceeded() {
        var active = true
        let monitor = KeyboardMonitor(accessibilityTrusted: { true }, createTap: { _, _ in nil })
        monitor.onStatus = { enabled, _ in active = enabled }
        monitor.refresh()
        XCTAssertFalse(active)
    }

    private func event(_ type: CGEventType, code: UInt16, flags: CGEventFlags = [], time: Double = 0, repeatKey: Bool = false) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: type != .keyUp)!
        event.type = type
        event.flags = flags
        event.timestamp = UInt64(time * 1_000_000_000)
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeatKey ? 1 : 0)
        return event
    }
    @discardableResult private func send(_ monitor: KeyboardMonitor, _ type: CGEventType, code: UInt16,
                                         flags: CGEventFlags = [], time: Double = 0, repeatKey: Bool = false) -> Bool {
        monitor.receive(type: type, event: event(type, code: code, flags: flags, time: time, repeatKey: repeatKey)) == nil
    }

    func testCapturedChordSwallowsRepeatAndMatchingKeyUpOnly() {
        let monitor = KeyboardMonitor()
        var deliveries: [UInt16] = []
        monitor.onKeyDown = { code, flags, repeated in
            deliveries.append(code)
            return code == 0 && flags == .control && !repeated
        }
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: .maskControl))
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: .maskControl, repeatKey: true))
        XCTAssertTrue(send(monitor, .keyUp, code: 0)) // still consumed after Control is released
        XCTAssertFalse(send(monitor, .keyDown, code: 1, flags: .maskControl))
        XCTAssertFalse(send(monitor, .keyUp, code: 1))
        XCTAssertEqual(deliveries, [0, 1])
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: .maskControl)) // no sticky capture
        XCTAssertEqual(deliveries, [0, 1, 0])
    }

    func testRealModifierEventSequenceAndInterveningChord() {
        let monitor = KeyboardMonitor()
        var summons = 0
        monitor.onSummon = { summons += 1 }
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0)
        send(monitor, .flagsChanged, code: 59, time: 0.05)
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0.1)
        send(monitor, .flagsChanged, code: 59, time: 0.15)
        XCTAssertEqual(summons, 1)
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0.3)
        send(monitor, .keyDown, code: 0, flags: .maskControl, time: 0.32)
        send(monitor, .flagsChanged, code: 59, time: 0.35)
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0.4)
        send(monitor, .flagsChanged, code: 59, time: 0.45)
        XCTAssertEqual(summons, 1)
    }

    func testMissingKeyUpDoesNotSwallowNextFreshPress() {
        let monitor = KeyboardMonitor()
        var deliveries = 0
        monitor.onKeyDown = { _, _, _ in deliveries += 1; return true }
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: .maskControl))
        // The event tap may miss key-up during secure input or a session transition.
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: .maskControl))
        XCTAssertEqual(deliveries, 2)
    }

    func testTwoControlKeysHeldTogetherCannotBecomeDoubleTap() {
        let monitor = KeyboardMonitor()
        var summons = 0
        monitor.onSummon = { summons += 1 }
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0)
        send(monitor, .flagsChanged, code: 62, flags: .maskControl, time: 0.05)
        send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: 0.1)
        send(monitor, .flagsChanged, code: 62, time: 0.15)
        XCTAssertEqual(summons, 0)
    }

    func testDisabledGesturesStillDetectGlobeAndCapsLockDoesNotChangeChord() {
        let monitor = KeyboardMonitor()
        monitor.gesturesEnabled = false
        var summons = 0
        var globeEvents = 0
        monitor.onSummon = { summons += 1 }
        monitor.onGlobe = { globeEvents += 1 }
        for time in [0.0, 0.15] {
            send(monitor, .flagsChanged, code: 59, flags: .maskControl, time: time)
            send(monitor, .flagsChanged, code: 59, time: time + 0.05)
        }
        send(monitor, .flagsChanged, code: 63, flags: .maskSecondaryFn, time: 0.3)
        XCTAssertEqual(summons, 0)
        XCTAssertEqual(globeEvents, 1)
        monitor.onKeyDown = { _, flags, _ in flags == .control }
        XCTAssertTrue(send(monitor, .keyDown, code: 0, flags: [.maskControl, .maskAlphaShift]))
    }
}
