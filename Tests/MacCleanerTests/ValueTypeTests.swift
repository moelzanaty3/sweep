import XCTest
@testable import MacCleaner

final class ValueTypeTests: XCTestCase {
    func testFormatAgeCoversEveryBucket() {
        func age(daysAgo: Double) -> String {
            formatAge(Date().addingTimeInterval(-daysAgo * 86_400))
        }

        XCTAssertEqual(formatAge(nil), "—")
        XCTAssertEqual(age(daysAgo: 0.2), "today")
        XCTAssertEqual(age(daysAgo: 1.2), "1 day ago")
        XCTAssertEqual(age(daysAgo: 9), "9 days ago")
        XCTAssertTrue(age(daysAgo: 90).hasSuffix("mo ago"))
        XCTAssertTrue(age(daysAgo: 800).hasSuffix("yr ago"))
    }

    func testCategoryIdentifiersMatchTheirNames() {
        for category in Category.allCases {
            XCTAssertEqual(category.id, category.rawValue)
        }
    }

    func testDiskSnapshotArithmetic() {
        let snapshot = DiskSnapshot(total: 1_000, free: 250)

        XCTAssertEqual(snapshot.used, 750)
        XCTAssertEqual(snapshot.usedFraction, 0.75, accuracy: 0.0001)
    }

    /// An empty volume must not divide by zero, and free space larger than the
    /// total must not report negative usage.
    func testDiskSnapshotHandlesDegenerateValues() {
        XCTAssertEqual(DiskSnapshot().usedFraction, 0)
        XCTAssertEqual(DiskSnapshot(total: 0, free: 0).used, 0)
        XCTAssertEqual(DiskSnapshot(total: 100, free: 200).used, 0)
    }

    func testItemIsEmptyWhenItWouldFreeNothing() {
        func item(bytes: Int64) -> CleanItem {
            CleanItem(id: "a", title: "A", detail: "", paths: [], risk: .safe,
                      category: .devCaches, bytes: bytes)
        }

        XCTAssertTrue(item(bytes: 0).isEmpty)
        XCTAssertTrue(item(bytes: -1).isEmpty)
        XCTAssertFalse(item(bytes: 1).isEmpty)
    }

    func testDisposalCasesAreIdentifiable() {
        for disposal in Cleaner.Disposal.allCases {
            XCTAssertEqual(disposal.id, disposal.rawValue)
            XCTAssertFalse(disposal.id.isEmpty)
        }
    }

    /// The Docker disk image is reported rather than deleted, so the accessor
    /// must only ever return paths that exist.
    func testDockerDiskImagePathsOnlyReturnsRealFiles() {
        for path in Catalog.dockerDiskImagePaths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "\(path) does not exist")
            XCTAssertTrue(path.hasPrefix(NSHomeDirectory()))
        }
    }

    func testEveryPathSpecResolvesUnderTheHomeDirectory() {
        for spec in Catalog.devCaches + Catalog.appJunk {
            for path in spec.absolutePaths {
                XCTAssertTrue(path.hasPrefix(NSHomeDirectory()), "\(spec.id) escapes home: \(path)")
            }
        }
    }
}
