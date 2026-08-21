import XCTest
@testable import MacCleaner

/// The tool actions shell out to docker, brew, go and git. Running those for
/// real would mutate the machine the suite runs on, so these swap in a stub and
/// assert on the command chosen and how its result is interpreted.
final class CleanerActionTests: XCTestCase {
    private var invocations: [(path: String, args: [String])] = []

    override func tearDown() {
        Cleaner.runner = nil
        invocations = []
    }

    private func stub(status: Int32, out: String = "") {
        Cleaner.runner = { [self] path, args, _ in
            invocations.append((path, args))
            return ShellResult(status: status, out: out)
        }
    }

    private func item(_ action: ToolAction, paths: [String] = [], bytes: Int64 = 4_096) -> CleanItem {
        CleanItem(id: "tool", title: "Tool item", detail: "", paths: paths,
                  risk: .safe, category: .tools, bytes: bytes, action: action)
    }

    func testEachActionRunsItsOwnCommand() async {
        let expected: [(ToolAction, String)] = [
            (.dockerPrune, "docker"),
            (.dockerBuilderPrune, "builder"),
            (.brewCleanup, "brew"),
            (.simctlDeleteUnavailable, "simctl"),
            (.pnpmStorePrune, "pnpm"),
            (.goCleanModcache, "go")
        ]

        for (action, marker) in expected {
            invocations = []
            stub(status: 0)
            let outcome = await Cleaner.clean(item(action), disposal: .delete)

            XCTAssertTrue(outcome.succeeded, "\(action) should succeed on exit 0")
            XCTAssertEqual(invocations.count, 1)
            XCTAssertTrue(invocations[0].args.contains(marker),
                          "\(action) ran \(invocations[0].args), expected it to mention \(marker)")
        }
    }

    func testSuccessReportsTheItemSizeAsFreed() async {
        stub(status: 0)
        let outcome = await Cleaner.clean(item(.brewCleanup, bytes: 2_048), disposal: .delete)

        XCTAssertEqual(outcome.freed, 2_048)
        XCTAssertTrue(outcome.message.contains("reclaimed"), outcome.message)
    }

    /// 127 is "command not found". Reporting the raw exit code there would tell
    /// the user nothing actionable.
    func testMissingToolIsReportedAsNotInstalled() async {
        stub(status: 127)
        let outcome = await Cleaner.clean(item(.goCleanModcache), disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.message, "tool not installed")
        XCTAssertEqual(outcome.freed, 0)
    }

    func testFailureSurfacesTheFirstLineOfOutput() async {
        stub(status: 1, out: "Cannot connect to the Docker daemon\nsecond line ignored")
        let outcome = await Cleaner.clean(item(.dockerPrune), disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.message, "Cannot connect to the Docker daemon")
    }

    func testSilentFailureFallsBackToTheExitCode() async {
        stub(status: 3)
        let outcome = await Cleaner.clean(item(.brewCleanup), disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.message, "exit 3")
    }

    func testGitCollectRunsAgainstTheRepositoryPath() async {
        stub(status: 0)
        let repo = "\(NSHomeDirectory())/Desktop/some-repo"
        let outcome = await Cleaner.clean(item(.gitGarbageCollect, paths: [repo]), disposal: .delete)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(invocations[0].args, ["git", "-C", repo, "gc", "--prune=now", "--quiet"])
    }

    func testGitCollectWithoutAPathIsRefusedRatherThanRun() async {
        stub(status: 0)
        let outcome = await Cleaner.clean(item(.gitGarbageCollect), disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.message, "no repository path")
        XCTAssertTrue(invocations.isEmpty, "nothing should be executed without a repository")
    }

    /// A path item that merely prefers a command falls back to plain removal
    /// when the user picked Trash, so the file is recoverable.
    func testTrashDisposalDoesNotDelegateToTheTool() async {
        stub(status: 0)
        let path = "\(NSHomeDirectory())/Library/Caches/sweep-test-nonexistent"
        _ = await Cleaner.clean(item(.pnpmStorePrune, paths: [path]), disposal: .trash)

        XCTAssertTrue(invocations.isEmpty, "Trash must not run the tool command")
    }

    func testDeleteFailureIsReported() async {
        stub(status: 1, out: "rm: permission denied")
        let root = try? TempHome.makeDirectory("delete-failure")
        defer { if let root { TempHome.remove(root) } }
        guard let root else { return XCTFail("could not make a scratch directory") }
        let victim = "\(root)/target"
        try? TempHome.write("x", to: victim)

        let outcome = await Cleaner.clean(
            CleanItem(id: "x", title: "X", detail: "", paths: [victim],
                      risk: .safe, category: .devCaches, bytes: 1),
            disposal: .delete)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.message, "rm: permission denied")
    }
}
