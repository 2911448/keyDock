import XCTest
import AppKit
@testable import KeyDock

final class KeyboardPanelTests: XCTestCase {
    func testBackgroundPanelDoesNotDependOnApplicationActivation() {
        _ = NSApplication.shared
        let panel = KeyboardPanel()
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    func testFocusLossNotifiesOwnerToKeepVisibilityStateInSync() {
        _ = NSApplication.shared
        let panel = KeyboardPanel()
        var dismissals = 0
        panel.onFocusLost = { dismissals += 1 }
        panel.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification, object: panel))
        XCTAssertEqual(dismissals, 1)
    }
}
