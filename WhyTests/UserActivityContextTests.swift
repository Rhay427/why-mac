import XCTest
@testable import Why

final class UserActivityContextTests: XCTestCase {
    func testCaptureReturnsAggregateSessionCounterSample() {
        XCTAssertNotNil(UserActivityContextProbe().capture())
    }

    func testChangedCounterIsPositiveEvidenceOfActivity() {
        XCTAssertEqual(
            UserActivityContextProbe().context(between: 100, and: 101),
            .active
        )
    }

    func testUnchangedCounterRemainsUnknown() {
        XCTAssertEqual(
            UserActivityContextProbe().context(between: 100, and: 100),
            .unknown
        )
    }

    func testUnavailableCounterRemainsUnknown() {
        XCTAssertEqual(UserActivityContextProbe().context(between: nil, and: 101), .unknown)
        XCTAssertEqual(UserActivityContextProbe().context(between: 100, and: nil), .unknown)
    }
}
