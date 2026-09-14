import AppKit

final class KeyboardPanel: NSPanel, NSWindowDelegate {
    var onFocusLost: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1010, height: 462),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        // This panel takes keyboard focus while the foreground app stays active.
        // App activation must not control its visibility or silently desync the model.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        title = "KeyDock"
        identifier = NSUserInterfaceItemIdentifier("KeyDockKeyboard")
        delegate = self
    }

    func windowDidResignKey(_ notification: Notification) {
        // The binding picker owns focus temporarily while its parent stays visible.
        guard attachedSheet == nil else { return }
        onFocusLost?()
    }
}
