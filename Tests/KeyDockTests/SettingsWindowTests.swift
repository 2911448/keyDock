import XCTest
import AppKit
@testable import KeyDock

final class SettingsWindowTests: XCTestCase {
    func testSettingsIsNormalIndependentClosableWindow() {
        _ = NSApplication.shared
        let controller = SettingsWindowController(contentView: NSView())
        let window = controller.window!
        XCTAssertFalse(window is NSPanel)
        XCTAssertEqual(window.level, .normal)
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertFalse(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertNil(window.sheetParent)
        XCTAssertNil(window.parent)
    }

    func testSettingsDoesNotKeepKeyboardPausedAfterLosingFocusOrClosing() {
        _ = NSApplication.shared
        let controller = SettingsWindowController(contentView: NSView())
        var focused = false
        controller.onFocusChange = { focused = $0 }
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        XCTAssertTrue(focused)
        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        XCTAssertFalse(focused)
        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        controller.windowWillClose(Notification(name: NSWindow.willCloseNotification))
        XCTAssertFalse(focused)
    }
}
