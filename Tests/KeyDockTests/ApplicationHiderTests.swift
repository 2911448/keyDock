import XCTest
@testable import KeyDock

final class ApplicationHiderTests: XCTestCase {
    @MainActor func testNativeFailureFallsBackAndWaitsForActualHiddenState() async {
        var fallbackSent = false
        var hidden = false
        var waits = 0
        let result = await ApplicationHider.perform(isHidden: { hidden }, isTerminated: { false },
            requestHide: { false }, fallback: { fallbackSent = true; return true },
            wait: { waits += 1; if fallbackSent { hidden = true } })
        XCTAssertTrue(result)
        XCTAssertTrue(fallbackSent)
        XCTAssertEqual(waits, 2)
    }

    @MainActor func testDelayedNativeSuccessDoesNotSendFallback() async {
        var waits = 0
        let result = await ApplicationHider.perform(isHidden: { waits >= 2 }, isTerminated: { false },
            requestHide: { true }, fallback: { XCTFail("Native hide already succeeded"); return false },
            wait: { waits += 1 })
        XCTAssertTrue(result)
        XCTAssertEqual(waits, 2)
    }

    @MainActor func testAcceptedRequestsWithoutVisibilityChangeAreNotSuccess() async {
        var fallbackSent = false
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { false },
            requestHide: { true }, fallback: { fallbackSent = true; return true }, wait: {})
        XCTAssertFalse(result)
        XCTAssertTrue(fallbackSent)
    }

    @MainActor func testPermissionDeniedFallbackReportsFailure() async {
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { false },
            requestHide: { false }, fallback: { false }, wait: {})
        XCTAssertFalse(result)
    }

    @MainActor func testExitDuringRequestStopsBeforeAccessibilityFallback() async {
        var exited = false
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { exited },
            requestHide: { false }, fallback: { XCTFail("Do not contact exited apps"); return false },
            wait: { exited = true })
        XCTAssertFalse(result)
    }
}
