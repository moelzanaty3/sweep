import XCTest
@testable import MacCleaner

/// The highest-value tests in this repository. `isRemovable` is the last check
/// before anything is deleted, so every clause of it is pinned here. A change
/// that widens deletion has to break one of these first.
final class CleanerSafetyTests: XCTestCase {
    private var home: String { URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path }

    // MARK: - Outside the home directory

    func testRefusesSystemPaths() {
        for path in ["/", "/System", "/usr/bin", "/Library", "/private/var", "/Applications",
                     "/etc/passwd", "/Volumes/External/stuff"] {
            XCTAssertFalse(Cleaner.isRemovable(path), "must refuse \(path)")
        }
    }

    func testRefusesAnotherUsersHome() {
        XCTAssertFalse(Cleaner.isRemovable("/Users/someone-else/Library/Caches/npm"))
    }

    func testRefusesTheHomeDirectoryItself() {
        XCTAssertFalse(Cleaner.isRemovable(home))
        XCTAssertFalse(Cleaner.isRemovable(home + "/"))
    }

    // MARK: - Traversal

    func testRefusesParentTraversal() {
        XCTAssertFalse(Cleaner.isRemovable(home + "/Library/../../../etc"))
        XCTAssertFalse(Cleaner.isRemovable(home + "/../Shared"))
    }

    /// A traversal that resolves back inside the home directory is fine — the
    /// guard standardizes before it compares, so this is about the resolved
    /// path, never the spelling.
    func testAcceptsTraversalThatResolvesInsideHome() {
        XCTAssertTrue(Cleaner.isRemovable(home + "/Library/Caches/../Caches/npm"))
    }

    // MARK: - Depth

    func testRefusesTopLevelHomeFolders() {
        for name in ["Documents", "Desktop", "Downloads", "Library", "Pictures", "Movies", "Music"] {
            XCTAssertFalse(Cleaner.isRemovable("\(home)/\(name)"), "must refuse ~/\(name)")
        }
    }

    func testAcceptsSufficientlyDeepPaths() {
        XCTAssertTrue(Cleaner.isRemovable(home + "/Library/Caches/com.example.app"))
        XCTAssertTrue(Cleaner.isRemovable(home + "/Desktop/project/node_modules"))
    }

    /// Depth is waived only for paths the catalog named explicitly.
    func testAcceptsShallowPathsOnlyWhenTheCatalogNamesThem() {
        let shallow = Catalog.explicitCachePaths.filter { path in
            path.dropFirst(home.count + 1).split(separator: "/").count < 2
        }
        for path in shallow {
            XCTAssertTrue(Cleaner.isRemovable(path), "catalog named \(path) but it was refused")
        }
        XCTAssertFalse(Cleaner.isRemovable(home + "/not-in-the-catalog"))
    }

    // MARK: - Protected trees

    func testRefusesCredentialAndSyncTrees() {
        let mustRefuse = [
            "/.ssh", "/.ssh/id_rsa",
            "/.gnupg", "/.gnupg/private-keys-v1.d",
            "/Library/Keychains", "/Library/Keychains/login.keychain-db",
            "/Library/Preferences", "/Library/Preferences/com.apple.finder.plist",
            "/Library/Application Support/com.apple.sharedfilelist",
            "/Library/Mobile Documents", "/Library/Mobile Documents/com~apple~CloudDocs/Taxes"
        ]
        for suffix in mustRefuse {
            XCTAssertFalse(Cleaner.isRemovable(home + suffix), "must refuse ~\(suffix)")
        }
    }

    /// The guard matches on prefixes, so a sibling that merely starts with the
    /// same letters must not be swept up with it.
    func testProtectedPrefixesDoNotOverreach() {
        XCTAssertTrue(Cleaner.isRemovable(home + "/Library/Application Support/com.example.app"))
    }

    // MARK: - Every catalog path the app can actually offer

    func testEveryCatalogPathPassesItsOwnGuard() {
        for path in Catalog.explicitCachePaths {
            XCTAssertTrue(Cleaner.isRemovable(path), "catalog offers \(path) but the guard refuses it")
        }
    }
}
