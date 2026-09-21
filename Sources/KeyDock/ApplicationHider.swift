import AppKit

@MainActor
enum ApplicationHider {
    static func hide(_ application: NSRunningApplication) async -> Bool {
        await perform(isHidden: { application.isHidden }, isTerminated: { application.isTerminated },
                      requestHide: { application.hide() }, wait: { try? await Task.sleep(nanoseconds: 75_000_000) })
    }
    static func perform(isHidden: () -> Bool, isTerminated: () -> Bool,
                        requestHide: () -> Bool, wait: () async -> Void) async -> Bool {
        guard !isTerminated() else { return false }
        if isHidden() { return true }
        let accepted = requestHide()
        for _ in 0..<(accepted ? 8 : 1) {
            await wait()
            guard !isTerminated() else { return false }
            if isHidden() { return true }
        }
        return false
    }
}
