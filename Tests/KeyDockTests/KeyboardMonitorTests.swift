import XCTest
import AppKit
import Carbon
import KeyDockCore
@testable import KeyDock

private final class FakeRegistrar: HotKeyRegistrar {
    var keys: [UInt32: (UInt16, Modifier)] = [:]
    var conflicts = Set<UInt32>()
    var installResult: OSStatus = noErr
    func start(_ receive: @escaping (UInt32, Bool) -> Void) -> OSStatus { installResult }
    func register(id: UInt32, key: UInt16, modifier: Modifier) -> OSStatus {
        if conflicts.contains(id) { return OSStatus(eventHotKeyExistsErr) }
        keys[id] = (key, modifier)
        return noErr
    }
    func unregisterAll() { keys.removeAll() }
}

final class KeyboardMonitorTests: XCTestCase {
    private func config() -> Configuration {
        var c = Configuration()
        c.bindings = [AppBinding(keyCode: 0, bundleIdentifier: nil, path: "/A.app", name: "A")]
        return c
    }
    func testOnlyBoundKeysAndSummonRegisterAndPrefixChangesImmediately() {
        let registrar = FakeRegistrar()
        let subject = KeyboardMonitor(registrar: registrar)
        var c = config()
        subject.configure(c); subject.start()
        XCTAssertEqual(Set(registrar.keys.keys), [0, 1])
        XCTAssertEqual(registrar.keys[0]?.0, 49)
        XCTAssertEqual(registrar.keys[1]?.1, .control)
        c.prefix = .command
        subject.configure(c)
        XCTAssertEqual(registrar.keys[1]?.1, .command)
        c.bindings = []
        subject.configure(c)
        XCTAssertEqual(Set(registrar.keys.keys), [0])
    }
    func testHoldDispatchesOnceAndReleaseAllowsNextPress() {
        let subject = KeyboardMonitor(registrar: FakeRegistrar())
        subject.configure(config()); subject.start()
        var calls = 0
        subject.onKeyDown = { key, flags, repeated in
            XCTAssertEqual(key, 0); XCTAssertEqual(flags, .control); XCTAssertFalse(repeated)
            calls += 1; return true
        }
        subject.receive(id: 1, down: true); subject.receive(id: 1, down: true)
        subject.receive(id: 88, down: true)
        XCTAssertEqual(calls, 1)
        subject.receive(id: 1, down: false); subject.receive(id: 1, down: true)
        XCTAssertEqual(calls, 2)
    }
    func testPauseAndEditingReleaseChordsAndResumeClearsHeldState() {
        let registrar = FakeRegistrar()
        let monitor = KeyboardMonitor(registrar: registrar)
        monitor.configure(config()); monitor.start()
        var calls = 0
        monitor.onSummon = { calls += 1 }
        monitor.receive(id: 0, down: true)
        monitor.gesturesEnabled = false
        XCTAssertTrue(registrar.keys.isEmpty)
        monitor.receive(id: 0, down: true)
        XCTAssertEqual(calls, 1)
        monitor.gesturesEnabled = true
        monitor.receive(id: 0, down: true)
        XCTAssertEqual(calls, 2)
    }
    func testConflictDoesNotClaimSuccessOrDisableWorkingChords() {
        let registrar = FakeRegistrar(); registrar.conflicts = [0]
        let subject = KeyboardMonitor(registrar: registrar)
        subject.configure(config())
        var active = true, status = "", calls = 0
        subject.onStatus = { active = $0; status = $1 }
        subject.onKeyDown = { _, _, _ in calls += 1; return true }
        subject.onSummon = { XCTFail("Unregistered summon cannot dispatch") }
        subject.start()
        XCTAssertFalse(active); XCTAssertTrue(status.contains("空格"))
        subject.receive(id: 0, down: true); subject.receive(id: 1, down: true)
        XCTAssertEqual(calls, 1)
        registrar.conflicts = []; subject.retry()
        XCTAssertTrue(active)
    }
    func testHandlerInstallFailureDoesNotRegisterKeys() {
        let registrar = FakeRegistrar(); registrar.installResult = OSStatus(paramErr)
        let subject = KeyboardMonitor(registrar: registrar)
        var active = true
        subject.onStatus = { active = $0; _ = $1 }
        subject.start()
        XCTAssertFalse(active); XCTAssertTrue(registrar.keys.isEmpty)
    }
}
