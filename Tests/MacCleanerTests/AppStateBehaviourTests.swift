import ServiceManagement
import XCTest
@testable import MacCleaner

/// Selection, derived totals, roots and the system-facing actions. Everything
/// that reaches outside the process goes through AppState.System, which is
/// stubbed here rather than opening panels or registering login items.
@MainActor
final class AppStateBehaviourTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var state: AppState!

    override func setUp() {
        suiteName = "sweep.behaviour.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        state = AppState(defaults: defaults)
    }

    override func tearDown() {
        AppState.System.reset()
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func item(_ id: String, risk: Risk = .safe, bytes: Int64 = 100,
                      category: MacCleaner.Category = .devCaches, paths: [String] = ["/tmp/x"]) -> CleanItem {
        CleanItem(id: id, title: id, detail: "", paths: paths, risk: risk,
                  category: category, bytes: bytes)
    }

    private func seed() {
        state.itemsByCategory[.devCaches] = [item("a", bytes: 100), item("b", risk: .rebuild, bytes: 250)]
        state.itemsByCategory[.largeFiles] = [item("c", risk: .protected, bytes: 400, category: MacCleaner.Category.largeFiles)]
    }

    // MARK: - Derived values

    func testTotalsAndDerivedCollections() {
        seed()

        XCTAssertEqual(state.total(in: .devCaches), 350)
        XCTAssertEqual(state.reclaimableTotal, 750)
        XCTAssertEqual(state.safeTotal, 100)
        XCTAssertEqual(state.reviewTotal, 650)
        XCTAssertEqual(state.allItems.count, 3)
        XCTAssertEqual(Set(state.scannedCategories), [.devCaches, .largeFiles])
    }

    func testScanningFlagFollowsTheInFlightSet() {
        XCTAssertFalse(state.isScanning)
        state.scanning.insert(.devCaches)
        XCTAssertTrue(state.isScanning)
        state.scanning.removeAll()
        XCTAssertFalse(state.isScanning)
    }

    func testSelectedItemsAndBytes() {
        seed()
        state.toggle(item("a"))
        state.toggle(item("c", risk: .protected, bytes: 400, category: MacCleaner.Category.largeFiles))

        XCTAssertEqual(Set(state.selectedItems.map(\.id)), ["a", "c"])
        XCTAssertEqual(state.selectedBytes, 500)
    }

    func testToggleAddsThenRemoves() {
        seed()
        state.toggle(item("a"))
        XCTAssertTrue(state.selection.contains("a"))
        state.toggle(item("a"))
        XCTAssertFalse(state.selection.contains("a"))
    }

    func testSelectAndDeselectWholeCategory() {
        seed()
        state.selectAll(in: .devCaches)
        XCTAssertEqual(state.selection, ["a", "b"])

        state.deselectAll(in: .devCaches)
        XCTAssertTrue(state.selection.isEmpty)
    }

    func testMenuBarLabelRespondsToSizePreference() {
        seed()
        state.menuBarShowsSize = true
        XCTAssertFalse(state.menuBarLabel.isEmpty)

        state.menuBarShowsSize = false
        XCTAssertTrue(state.menuBarLabel.isEmpty)
    }

    // MARK: - Roots and allowlist

    func testRootsAreAddedThroughThePickerAndRemovedById() {
        let picked = "\(NSHomeDirectory())/Desktop/extra-root"
        AppState.System.pickFolders = { [picked] }

        state.addRoot(toProjects: true)
        XCTAssertTrue(state.projectRoots.contains(picked))
        state.removeRoot(picked, fromProjects: true)
        XCTAssertFalse(state.projectRoots.contains(picked))

        state.addRoot(toProjects: false)
        XCTAssertTrue(state.fileRoots.contains(picked))
        state.removeRoot(picked, fromProjects: false)
        XCTAssertFalse(state.fileRoots.contains(picked))
    }

    func testCancellingThePickerChangesNothing() {
        AppState.System.pickFolders = { nil }
        let before = state.projectRoots

        state.addRoot(toProjects: true)
        state.addAllowlistFolder()

        XCTAssertEqual(state.projectRoots, before)
        XCTAssertTrue(state.allowlist.isEmpty)
    }

    func testAllowlistFolderIsAddedThroughThePicker() {
        let picked = "\(NSHomeDirectory())/Desktop/never-touch"
        AppState.System.pickFolders = { [picked] }

        state.addAllowlistFolder()

        XCTAssertEqual(state.allowlist, [picked])
    }

    func testAddingAnItemToTheAllowlistUsesItsProjectFolder() {
        let path = "\(NSHomeDirectory())/Desktop/proj/node_modules"
        state.addToAllowlist(item("x", category: MacCleaner.Category.projects, paths: [path]))

        XCTAssertEqual(state.allowlist.count, 1)
        XCTAssertFalse(state.allowlist[0].hasSuffix("node_modules"), "the project, not the artifact")
    }

    // MARK: - Login item

    func testLaunchAtLoginReflectsServiceStatus() {
        AppState.System.loginItemStatus = { .enabled }
        XCTAssertTrue(state.launchAtLogin)
        XCTAssertFalse(state.launchAtLoginRequiresApproval)

        AppState.System.loginItemStatus = { .requiresApproval }
        XCTAssertFalse(state.launchAtLogin)
        XCTAssertTrue(state.launchAtLoginRequiresApproval)
    }

    func testEnablingLoginItemClearsAnyPreviousError() {
        var requested: Bool?
        AppState.System.setLoginItem = { requested = $0 }
        state.loginItemError = "stale"

        state.setLaunchAtLogin(true)

        XCTAssertEqual(requested, true)
        XCTAssertNil(state.loginItemError)
    }

    func testLoginItemFailureIsSurfacedRatherThanSwallowed() {
        struct Denied: LocalizedError {
            var errorDescription: String? { "registration denied" }
        }
        AppState.System.setLoginItem = { _ in throw Denied() }

        state.setLaunchAtLogin(true)

        XCTAssertEqual(state.loginItemError, "registration denied")
        XCTAssertTrue(state.activity.contains { $0.contains("Open at login failed") })
    }

    func testOpeningLoginItemsSettingsIsDelegated() {
        var opened = false
        AppState.System.openLoginItemsSettings = { opened = true }

        state.openLoginItemsSettings()

        XCTAssertTrue(opened)
    }

    // MARK: - Finder and notifications

    func testRevealPassesTheFirstPath() {
        var revealed: String?
        AppState.System.revealInFinder = { revealed = $0 }

        state.reveal(item("a", paths: ["/tmp/one", "/tmp/two"]))
        XCTAssertEqual(revealed, "/tmp/one")

        revealed = nil
        state.reveal(item("b", paths: []))
        XCTAssertNil(revealed, "nothing to reveal without a path")
    }

    func testNotificationAccessIsRequestedThroughTheSeam() {
        var asked = false
        AppState.System.requestNotificationAccess = { asked = true }

        state.requestNotificationAccess()

        XCTAssertTrue(asked)
    }

    // MARK: - Activity log

    func testActivityLogIsNewestFirstAndBounded() {
        for index in 0..<420 { state.log("entry \(index)") }

        XCTAssertEqual(state.activity.count, 400)
        XCTAssertTrue(state.activity[0].contains("entry 419"))
    }

    // MARK: - Schedule

    func testChangingTheIntervalIsPersisted() {
        state.scanInterval = .daily
        XCTAssertEqual(AppState(defaults: defaults).scanInterval, .daily)

        state.scanInterval = .off
        XCTAssertEqual(AppState(defaults: defaults).scanInterval, .off)
    }

    func testEveryEnumCaseIsPresentable() {
        for appearance in Appearance.allCases {
            XCTAssertFalse(appearance.label.isEmpty)
            XCTAssertFalse(appearance.icon.isEmpty)
            XCTAssertEqual(appearance.id, appearance.rawValue)
        }
        for interval in ScanInterval.allCases {
            XCTAssertFalse(interval.label.isEmpty)
            XCTAssertEqual(interval.id, interval.rawValue)
        }
        XCTAssertNil(Appearance.system.colorScheme)
        XCTAssertNotNil(Appearance.dark.colorScheme)
        XCTAssertNotNil(Appearance.light.colorScheme)
    }
}
