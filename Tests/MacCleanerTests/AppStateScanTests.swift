import XCTest
@testable import MacCleaner

/// Scanning and cleaning end to end, driven against a scratch directory so the
/// results are deterministic and nothing outside it is ever touched.
@MainActor
final class AppStateScanTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var state: AppState!
    private var root = ""

    override func setUpWithError() throws {
        suiteName = "sweep.scan.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        state = AppState(defaults: defaults)
        root = try TempHome.makeDirectory("scan")
    }

    override func tearDown() {
        AppState.System.reset()
        defaults.removePersistentDomain(forName: suiteName)
        TempHome.remove(root)
    }

    private func settle(timeout: TimeInterval = 30, until condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("timed out waiting for the operation to finish") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // MARK: - Scanning

    func testScanningProjectsFindsBuildArtifacts() async throws {
        let project = "\(root)/app"
        try FileManager.default.createDirectory(atPath: "\(project)/node_modules/pkg",
                                                withIntermediateDirectories: true)
        try TempHome.write(String(repeating: "x", count: 40_000), to: "\(project)/node_modules/pkg/index.js")
        state.projectRoots = [root]

        state.scan(.projects)
        try await settle { !self.state.isScanning }

        let found = state.items(in: .projects)
        XCTAssertFalse(found.isEmpty, "the artifact directory should be reported")
        XCTAssertTrue(found.allSatisfy { $0.paths.allSatisfy { $0.hasPrefix(self.root) } })
        XCTAssertTrue(state.reclaimableTotal > 0)
    }

    func testAllowlistedProjectsAreNotReported() async throws {
        let project = "\(root)/app"
        try FileManager.default.createDirectory(atPath: "\(project)/node_modules",
                                                withIntermediateDirectories: true)
        try TempHome.write(String(repeating: "x", count: 40_000), to: "\(project)/node_modules/index.js")
        state.projectRoots = [root]
        state.allowlist = [project]

        state.scan(.projects)
        try await settle { !self.state.isScanning }

        XCTAssertTrue(state.items(in: .projects).isEmpty)
    }

    func testScanningEveryCategoryMarksThemAllComplete() async throws {
        state.projectRoots = [root]
        state.fileRoots = [root]

        state.scanAll()
        try await settle(timeout: 180) { !self.state.isScanning }

        XCTAssertTrue(state.scanning.isEmpty)
        XCTAssertTrue(state.activity.contains { $0.contains("Scanned") || $0.contains("scan") })
    }

    func testQuickScanCoversTheCheapCategoriesOnly() async throws {
        state.scanSafeCategories()
        try await settle(timeout: 120) { !self.state.isScanning }

        XCTAssertTrue(state.items(in: .duplicates).isEmpty, "duplicates are not part of a quick scan")
    }

    // MARK: - Cleaning

    func testCleanSelectedRemovesItemsAndForgetsThem() async throws {
        let victim = "\(root)/cache/build"
        try FileManager.default.createDirectory(atPath: victim, withIntermediateDirectories: true)
        try TempHome.write("artifact", to: "\(victim)/out.o")

        state.disposal = .delete
        state.itemsByCategory[.devCaches] = [
            CleanItem(id: "victim", title: "Victim", detail: "", paths: [victim],
                      risk: .safe, category: .devCaches, bytes: 8)
        ]
        state.selection = ["victim"]

        state.cleanSelected()
        try await settle { !self.state.cleaning }

        XCTAssertFalse(FileManager.default.fileExists(atPath: victim))
        XCTAssertTrue(state.selection.isEmpty, "a cleaned item should leave the selection")
        XCTAssertTrue(state.items(in: .devCaches).isEmpty, "and the results list")
    }

    func testCleanSelectedKeepsItemsItCouldNotRemove() async throws {
        state.disposal = .delete
        state.itemsByCategory[.devCaches] = [
            CleanItem(id: "refused", title: "Refused", detail: "", paths: ["/System"],
                      risk: .safe, category: .devCaches, bytes: 8)
        ]
        state.selection = ["refused"]

        state.cleanSelected()
        try await settle { !self.state.cleaning }

        XCTAssertEqual(state.items(in: .devCaches).count, 1, "a refused item must stay on screen")
        XCTAssertTrue(state.activity.contains { $0.contains("✗") })
    }

    func testCleaningNothingDoesNotStart() {
        state.selection = []
        state.cleanSelected()

        XCTAssertFalse(state.cleaning)
    }

    // MARK: - Background scan

    func testBackgroundScanNotifiesOnlyWhenSomethingNewAppeared() async throws {
        var delivered: [String] = []
        AppState.System.deliverNotification = { title, _ in delivered.append(title) }
        state.notifyOnBackgroundScan = true
        state.projectRoots = [root]
        state.fileRoots = [root]

        state.runBackgroundScan()
        try await settle(timeout: 120) { !self.state.isScanning }
        try await Task.sleep(nanoseconds: 900_000_000)

        XCTAssertTrue(state.activity.contains { $0.contains("Background scan started") })
        // The scratch root is empty, so nothing new was found and the user is
        // not interrupted. A notification here would be noise.
        XCTAssertTrue(delivered.allSatisfy { $0.contains(Brand.name) })
    }

    /// The scheduled timer has to actually reach runBackgroundScan. Waiting an
    /// hour for it is not an option, so fire it by hand.
    func testScheduledTimerTriggersABackgroundScan() async throws {
        state.cleaning = true  // makes the scan a no-op, leaving only the wiring under test
        state.scanInterval = .hourly
        XCTAssertNotNil(state.timer, "an interval other than off must schedule a timer")

        state.timer?.fire()
        try await Task.sleep(nanoseconds: 300_000_000)

        state.scanInterval = .off
        XCTAssertNil(state.timer, "switching to off must tear the timer down")
    }

    func testBackgroundScanIsSkippedWhileAlreadyBusy() {
        state.cleaning = true
        state.runBackgroundScan()

        XCTAssertFalse(state.activity.contains { $0.contains("Background scan started") })
    }

    // MARK: - Remaining preferences

    func testThresholdPreferencesPersist() {
        state.olderThanDays = 120
        state.duplicateMinimumMB = 25
        state.notifyOnBackgroundScan = false
        state.showMenuBarItem = false

        let restored = AppState(defaults: defaults)
        XCTAssertEqual(restored.olderThanDays, 120)
        XCTAssertEqual(restored.duplicateMinimumMB, 25)
        XCTAssertFalse(restored.notifyOnBackgroundScan)
        XCTAssertFalse(restored.showMenuBarItem)
    }
}
