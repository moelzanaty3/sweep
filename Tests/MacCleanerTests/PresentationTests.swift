import XCTest
@testable import MacCleaner

final class PresentationTests: XCTestCase {
    func testFormatBytesCoversEachMagnitude() {
        XCTAssertEqual(formatBytes(0), "0 B")
        XCTAssertTrue(formatBytes(999).hasSuffix("B"))
        XCTAssertTrue(formatBytes(20_000).contains("KB"))
        XCTAssertTrue(formatBytes(5_000_000).contains("MB"))
        XCTAssertTrue(formatBytes(5_000_000_000).contains("GB"))
    }

    func testFormatBytesNeverReturnsEmpty() {
        for value: Int64 in [0, 1, 1024, 1_048_576, 1_073_741_824, Int64.max] {
            XCTAssertFalse(formatBytes(value).isEmpty)
        }
    }

    func testAbbreviateReplacesTheHomeDirectory() {
        let abbreviated = DiskScanner.abbreviate(NSHomeDirectory() + "/Desktop/thing")
        XCTAssertEqual(abbreviated, "~/Desktop/thing")
    }

    func testAbbreviateLeavesForeignPathsAlone() {
        XCTAssertEqual(DiskScanner.abbreviate("/usr/local/bin"), "/usr/local/bin")
    }

    /// Risk is the concept the whole UI is built on, so every tier has to carry
    /// a label and an explanation a stranger can act on.
    func testEveryRiskTierIsPresentable() {
        for risk in Risk.allCases {
            XCTAssertFalse(risk.label.isEmpty)
            XCTAssertFalse(risk.systemImage.isEmpty)
            XCTAssertGreaterThan(risk.explanation.count, 15, "\(risk) explanation is too thin")
        }
    }

    func testEveryCategoryIsPresentable() {
        for category in Category.allCases {
            XCTAssertFalse(category.rawValue.isEmpty)
            XCTAssertFalse(category.systemImage.isEmpty)
            XCTAssertGreaterThan(category.blurb.count, 20, "\(category) blurb is too thin")
        }
    }
}
