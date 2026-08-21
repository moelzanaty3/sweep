import XCTest
@testable import MacCleaner

/// The duplicate scanner decides which copy is presented as the one to keep.
/// Getting that backwards would point people at the wrong file to delete, which
/// is why it is worth the cost of touching the filesystem here.
final class DuplicateScannerTests: XCTestCase {
    private var root = ""

    override func setUpWithError() throws {
        root = try TempHome.makeDirectory("duplicates")
    }

    override func tearDown() {
        TempHome.remove(root)
    }

    private func makeFile(_ name: String, contents: String, ageInDays: Int) throws -> String {
        let path = "\(root)/\(name)"
        try TempHome.write(contents, to: path)
        let modified = Date().addingTimeInterval(-Double(ageInDays) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: path)
        return path
    }

    func testIdenticalFilesAreGroupedIntoOneSet() async throws {
        let body = String(repeating: "sweep", count: 4_000)
        _ = try makeFile("a.bin", contents: body, ageInDays: 10)
        _ = try makeFile("b.bin", contents: body, ageInDays: 5)
        _ = try makeFile("c.bin", contents: body, ageInDays: 1)

        let items = await DuplicateScanner.scan(roots: [root], minimumMB: 0, allowlist: [])

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(Set(items.compactMap(\.duplicateSet)).count, 1, "all three copies belong in one set")
        XCTAssertTrue(items.allSatisfy { $0.category == .duplicates })
    }

    func testNewestCopyIsTheOneMarkedAsPreferred() async throws {
        let body = String(repeating: "keep-the-newest", count: 2_000)
        _ = try makeFile("old.bin", contents: body, ageInDays: 30)
        let newest = try makeFile("new.bin", contents: body, ageInDays: 0)

        let items = await DuplicateScanner.scan(roots: [root], minimumMB: 0, allowlist: [])
        let preferred = items.filter(\.isPreferredCopy)

        XCTAssertEqual(preferred.count, 1, "exactly one copy in a set is the keeper")
        XCTAssertEqual(preferred.first?.paths.first, newest)
    }

    func testDifferentContentOfTheSameLengthIsNotADuplicate() async throws {
        _ = try makeFile("a.bin", contents: String(repeating: "a", count: 20_000), ageInDays: 2)
        _ = try makeFile("b.bin", contents: String(repeating: "b", count: 20_000), ageInDays: 1)

        let items = await DuplicateScanner.scan(roots: [root], minimumMB: 0, allowlist: [])

        XCTAssertTrue(items.isEmpty, "same size is not the same bytes")
    }

    func testAllowlistedPathsAreSkipped() async throws {
        let body = String(repeating: "excluded", count: 3_000)
        _ = try makeFile("a.bin", contents: body, ageInDays: 4)
        _ = try makeFile("b.bin", contents: body, ageInDays: 2)

        let items = await DuplicateScanner.scan(roots: [root], minimumMB: 0, allowlist: [root])

        XCTAssertTrue(items.isEmpty, "an allowlisted root must produce nothing")
    }

    func testEveryDuplicateIsProtectedNeverSafe() async throws {
        let body = String(repeating: "never-auto-select", count: 2_000)
        _ = try makeFile("a.bin", contents: body, ageInDays: 3)
        _ = try makeFile("b.bin", contents: body, ageInDays: 1)

        let items = await DuplicateScanner.scan(roots: [root], minimumMB: 0, allowlist: [])

        XCTAssertFalse(items.isEmpty)
        // "Select all safe" must never sweep up a duplicate, because only the
        // user knows which copy matters.
        XCTAssertTrue(items.allSatisfy { $0.risk == .protected })
    }
}
