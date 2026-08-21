import XCTest
@testable import MacCleaner

@MainActor
final class AppStateTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "sweep.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Defaults

    /// bool(forKey:) collapses "never set" and "set to false" into the same
    /// answer, which would silently reset every preference on first launch.
    func testUnsetPreferencesFallBackToTheirDefaults() {
        let state = AppState(defaults: defaults)

        XCTAssertEqual(state.disposal, .trash, "Trash must be the default disposal")
        XCTAssertTrue(state.showMenuBarItem)
        XCTAssertEqual(state.appearance, .system)
        XCTAssertEqual(state.scanInterval, .off)
    }

    func testStoredFalseIsNotMistakenForUnset() {
        defaults.set(false, forKey: "showMenuBarItem")

        XCTAssertFalse(AppState(defaults: defaults).showMenuBarItem)
    }

    func testPreferencesSurviveARestart() {
        let first = AppState(defaults: defaults)
        first.disposal = .delete
        first.appearance = .light
        first.minimumFileMB = 512

        let second = AppState(defaults: defaults)

        XCTAssertEqual(second.disposal, .delete)
        XCTAssertEqual(second.appearance, .light)
        XCTAssertEqual(second.minimumFileMB, 512)
    }

    func testRootsFallBackToTheCatalogWhenNothingIsStored() {
        let state = AppState(defaults: defaults)

        XCTAssertEqual(state.fileRoots, Catalog.defaultFileRoots)
        XCTAssertEqual(state.projectRoots, Catalog.defaultScanRoots)
    }

    // MARK: - Allowlist

    func testAllowlistRoundTrips() {
        let first = AppState(defaults: defaults)
        first.allowlist = ["\(NSHomeDirectory())/Desktop/keep"]

        XCTAssertEqual(AppState(defaults: defaults).allowlist, first.allowlist)
    }

    /// The key was renamed from "whitelist". An upgrade must not silently empty
    /// the one list whose entire purpose is preventing deletions.
    func testLegacyKeyIsMigrated() {
        let kept = "\(NSHomeDirectory())/Desktop/legacy-project"
        defaults.set(kept, forKey: "whitelist")

        XCTAssertEqual(AppState(defaults: defaults).allowlist, [kept])
    }

    func testTheNewKeyWinsWhenBothArePresent() {
        defaults.set("/old/path", forKey: "whitelist")
        defaults.set("/new/path", forKey: "allowlist")

        XCTAssertEqual(AppState(defaults: defaults).allowlist, ["/new/path"])
    }

    func testRemovingFromTheAllowlistPersists() {
        let state = AppState(defaults: defaults)
        state.allowlist = ["/a", "/b"]
        state.removeFromAllowlist("/a")

        XCTAssertEqual(AppState(defaults: defaults).allowlist, ["/b"])
    }

    // MARK: - Selection

    func testSelectionTogglesBothWays() {
        let state = AppState(defaults: defaults)
        state.itemsByCategory[.devCaches] = [
            CleanItem(id: "safe", title: "Safe", detail: "", paths: ["/x"],
                      risk: .safe, category: .devCaches, bytes: 100),
            CleanItem(id: "protected", title: "Protected", detail: "", paths: ["/y"],
                      risk: .protected, category: .devCaches, bytes: 200)
        ]

        state.toggleSafeSelection()
        XCTAssertTrue(state.hasSelection)
        XCTAssertTrue(state.selection.contains("safe"))
        // Selecting "everything safe" must never reach past the safe tier.
        XCTAssertFalse(state.selection.contains("protected"))

        state.toggleSafeSelection()
        XCTAssertFalse(state.hasSelection)
    }

    func testRiskTotalsOnlyCountTheirOwnTier() {
        let state = AppState(defaults: defaults)
        state.itemsByCategory[.devCaches] = [
            CleanItem(id: "a", title: "A", detail: "", paths: [], risk: .safe,
                      category: .devCaches, bytes: 100),
            CleanItem(id: "b", title: "B", detail: "", paths: [], risk: .rebuild,
                      category: .devCaches, bytes: 250)
        ]

        XCTAssertEqual(state.total(forRisk: .safe), 100)
        XCTAssertEqual(state.total(forRisk: .rebuild), 250)
        XCTAssertEqual(state.total(forRisk: .protected), 0)
        XCTAssertEqual(state.safeTotal, 100)
    }
}
