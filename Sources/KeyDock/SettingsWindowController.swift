import AppKit

/// Settings is a regular window, never a sheet on the floating launcher.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onFocusChange: ((Bool) -> Void)?

    init(contentView: NSView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 570),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "KeyDock 设置"
        window.identifier = NSUserInterfaceItemIdentifier("KeyDockSettings")
        window.level = .normal
        window.collectionBehavior = [.managed]
        window.isReleasedWhenClosed = false
        window.contentView = contentView
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present() {
        guard let window else { return }
        if !window.isVisible {
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            if let visibleFrame = screen?.visibleFrame {
                window.setFrameOrigin(NSPoint(x: visibleFrame.midX - window.frame.width / 2,
                                               y: visibleFrame.midY - window.frame.height / 2))
            } else { window.center() }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) { onFocusChange?(true) }
    func windowDidResignKey(_ notification: Notification) { onFocusChange?(false) }
    func windowWillClose(_ notification: Notification) { onFocusChange?(false) }
}
