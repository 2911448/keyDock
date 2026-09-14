import AppKit
import ApplicationServices

@MainActor
enum ApplicationHider {
    static func hide(_ application: NSRunningApplication) async -> Bool {
        await perform(isHidden: { application.isHidden },
                      isTerminated: { application.isTerminated },
                      requestHide: { application.hide() },
                      fallback: {
            let pid = application.processIdentifier
            return await withCheckedContinuation { continuation in
                // Accessibility IPC may wait for the other app. Keep it off the event-tap/UI thread.
                DispatchQueue.global(qos: .userInitiated).async {
                    let element = AXUIElementCreateApplication(pid)
                    AXUIElementSetMessagingTimeout(element, 0.5)
                    let result = AXUIElementSetAttributeValue(element, kAXHiddenAttribute as CFString, kCFBooleanTrue)
                    continuation.resume(returning: result == .success)
                }
            }
        }, wait: { try? await Task.sleep(nanoseconds: 75_000_000) })
    }

    // NSRunningApplication caches visibility until the main run loop advances.
    // A successful request alone is not proof that the other app actually hid.
    static func perform(isHidden: () -> Bool, isTerminated: () -> Bool,
                        requestHide: () -> Bool, fallback: () async -> Bool,
                        wait: () async -> Void) async -> Bool {
        guard !isTerminated() else { return false }
        if isHidden() { return true }
        let sent = requestHide()
        for _ in 0..<(sent ? 4 : 1) {
            await wait()
            guard !isTerminated() else { return false }
            if isHidden() { return true }
        }
        guard await fallback() else { return false }
        for _ in 0..<8 {
            await wait()
            guard !isTerminated() else { return false }
            if isHidden() { return true }
        }
        return false
    }
}
