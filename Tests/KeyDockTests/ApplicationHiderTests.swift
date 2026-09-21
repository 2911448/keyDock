import XCTest
@testable import KeyDock

final class ApplicationHiderTests: XCTestCase {
    @MainActor func testDelayedNativeSuccessWaitsForVisibility() async {
        var waits = 0
        let result = await ApplicationHider.perform(isHidden: { waits >= 2 }, isTerminated: { false },
            requestHide: { true }, wait: { waits += 1 })
        XCTAssertTrue(result); XCTAssertEqual(waits, 2)
    }
    @MainActor func testAcceptedRequestWithoutVisibilityChangeIsNotSuccess() async {
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { false }, requestHide: { true }, wait: {})
        XCTAssertFalse(result)
    }
    @MainActor func testRejectedNativeRequestFailsWithoutAnotherControlMechanism() async {
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { false }, requestHide: { false }, wait: {})
        XCTAssertFalse(result)
    }
    @MainActor func testExitDuringRequestDoesNotReportHidden() async {
        var exited = false
        let result = await ApplicationHider.perform(isHidden: { false }, isTerminated: { exited },
            requestHide: { true }, wait: { exited = true })
        XCTAssertFalse(result)
    }
}
