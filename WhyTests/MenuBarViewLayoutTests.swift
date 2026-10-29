import XCTest
@testable import Why

final class MenuBarViewLayoutTests: XCTestCase {
    func testMenuBarUsesReadableCompactWidth() {
        XCTAssertEqual(MenuBarView.preferredWidth, 380)
    }
}
