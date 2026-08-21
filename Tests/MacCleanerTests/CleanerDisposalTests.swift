import XCTest
@testable import MacCleaner

/// Deletion routing. These actually remove files, which is the only way to
/// prove the guard is consulted before the removal rather than after it.
final class CleanerDisposalTests: XCTestCase {
    private var root = ""

    override func setUpWithError() throws {
        root = try TempHome.makeDirectory("disposal")
    }

    override func tearDown() {
        TempHome.remove(root)
    }

    private func item(paths: [String], action: ToolAction? = nil) -> CleanItem {
        CleanItem(id: "test", title: "Test item", detail: "", paths: paths,
                  risk: .safe, category: .devCaches, bytes: 0, action: action)
    }

    func testDeleteRemovesThePath() async throws {
        let victim = "\(root)/build"
        try FileManager.default.createDirectory(atPath: victim, withIntermediateDirectories: true)
        try TempHome.write("artifact", to: "\(victim)/output.o")

        let outcome = await Cleaner.clean(item(paths: [victim]), disposal: .delete)

        XCTAssertTrue(outcome.succeeded, outcome.message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: victim))
    }

    func testTrashMovesThePathOutOfTheWay() async throws {
        let victim = "\(root)/cache-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(atPath: victim, withIntermediateDirectories: true)

        let outcome = await Cleaner.clean(item(paths: [victim]), disposal: .trash)

        XCTAssertTrue(outcome.succeeded, outcome.message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: victim))

        let trashed = "\(NSHomeDirectory())/.Trash/\((victim as NSString).lastPathComponent)"
        TempHome.remove(trashed)
    }

    /// The guard runs inside the disposal path, not only in the UI. A refused
    /// path must fail loudly and leave the file alone.
    func testRefusedPathIsReportedAndLeftUntouched() async throws {
        let outcome = await Cleaner.clean(item(paths: ["/etc/hosts"]), disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(outcome.message.contains("refused"), outcome.message)
        XCTAssertEqual(outcome.freed, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/etc/hosts"))
    }

    func testAMixOfRefusedAndAllowedPathsStillFails() async throws {
        let allowed = "\(root)/ok"
        try FileManager.default.createDirectory(atPath: allowed, withIntermediateDirectories: true)

        let outcome = await Cleaner.clean(item(paths: [allowed, "/System"]), disposal: .delete)

        // The allowed path goes, but the outcome must not claim success while
        // something was refused.
        XCTAssertFalse(outcome.succeeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: allowed))
    }

    /// Trashing needs write permission on the parent directory. When it is
    /// denied the failure has to be reported, not swallowed as success.
    func testTrashFailureIsReportedWithTheUnderlyingReason() async throws {
        let locked = "\(root)/locked"
        try FileManager.default.createDirectory(atPath: locked, withIntermediateDirectories: true)
        let victim = "\(locked)/cache/file.bin"
        try FileManager.default.createDirectory(atPath: "\(locked)/cache", withIntermediateDirectories: true)
        try TempHome.write("payload", to: victim)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked) }

        let outcome = await Cleaner.clean(item(paths: ["\(locked)/cache"]), disposal: .trash)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertFalse(outcome.message.isEmpty)
        XCTAssertTrue(outcome.message.contains("~/"), "the reason should name the path: \(outcome.message)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: victim), "the file must survive a failed trash")
    }

    func testMissingPathIsNotAFailure() async throws {
        let outcome = await Cleaner.clean(item(paths: ["\(root)/never-existed"]), disposal: .delete)

        XCTAssertTrue(outcome.succeeded, outcome.message)
        XCTAssertEqual(outcome.freed, 0)
    }

    /// A tool item with no paths has nothing to trash, so its command runs
    /// whichever disposal is selected. A path item that merely prefers a
    /// command falls back to plain removal when the user chose Trash.
    func testDisposalDecidesBetweenCommandAndRemoval() async throws {
        let victim = "\(root)/store"
        try FileManager.default.createDirectory(atPath: victim, withIntermediateDirectories: true)

        let outcome = await Cleaner.clean(item(paths: [victim], action: .pnpmStorePrune), disposal: .trash)

        XCTAssertTrue(outcome.succeeded, outcome.message)
        XCTAssertFalse(FileManager.default.fileExists(atPath: victim), "Trash must not delegate to the tool")

        let trashed = "\(NSHomeDirectory())/.Trash/store"
        TempHome.remove(trashed)
    }
}
