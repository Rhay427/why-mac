import AppKit
import XCTest
@testable import Why

final class BrandingTests: XCTestCase {
    func testDedicatedWhyLogoAssetIsPackaged() {
        XCTAssertNotNil(NSImage(named: "WhyLogo"))
    }
}
