import XCTest
@testable import MacCleaner

/// These enforce the rules CONTRIBUTING.md asks contributors to follow, so a
/// new cache entry that skips a rationale or reuses an id fails here rather
/// than shipping.
final class CatalogTests: XCTestCase {
    private var allSpecs: [PathSpec] { Catalog.devCaches + Catalog.appJunk }

    func testIdentifiersAreUnique() {
        let ids = allSpecs.map(\.id) + Catalog.toolActions.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate catalog id")
    }

    func testEverySpecIsFullyPopulated() {
        for spec in allSpecs {
            XCTAssertFalse(spec.id.isEmpty)
            XCTAssertFalse(spec.title.isEmpty, "\(spec.id) has no title")
            XCTAssertFalse(spec.relativePaths.isEmpty, "\(spec.id) names no paths")
            for path in spec.relativePaths {
                XCTAssertFalse(path.hasPrefix("/"), "\(spec.id) uses an absolute path: \(path)")
                XCTAssertFalse(path.contains(".."), "\(spec.id) traverses upward: \(path)")
            }
        }
    }

    func testEverySpecHasAHandWrittenRationale() {
        for spec in allSpecs {
            let rationale = Catalog.rationale(for: spec.id, risk: spec.risk)
            XCTAssertFalse(rationale.isEmpty, "\(spec.id) has no rationale")
            XCTAssertGreaterThan(rationale.count, 20, "\(spec.id) rationale is too thin to be useful")
        }
    }

    func testRationaleAlwaysFallsBackRatherThanReturningEmpty() {
        for risk in Risk.allCases {
            XCTAssertFalse(Catalog.rationale(for: "no-such-id", risk: risk).isEmpty)
        }
    }

    /// Reaching into these trips the Photos and Apple Music privacy prompts on
    /// mere traversal, and the libraries must never be cleaned piecemeal.
    func testMediaFoldersAreNotScannedByDefault() {
        for root in Catalog.defaultFileRoots {
            XCTAssertFalse(root.hasSuffix("/Pictures"), "Pictures must not be a default root")
            XCTAssertFalse(root.hasSuffix("/Movies"), "Movies must not be a default root")
            XCTAssertFalse(root.hasSuffix("/Music"), "Music must not be a default root")
        }
    }

    func testMediaLibraryBundlesAreTreatedAsOpaque() {
        for suffix in ["photoslibrary", "musiclibrary", "tvlibrary"] {
            XCTAssertTrue(Catalog.opaqueBundleSuffixes.contains(suffix), "\(suffix) must be opaque")
        }
    }

    func testDefaultRootsResolveInsideTheHomeDirectory() {
        let home = NSHomeDirectory()
        for root in Catalog.defaultFileRoots + Catalog.defaultScanRoots {
            XCTAssertTrue(root.hasPrefix(home), "\(root) is outside the home directory")
        }
    }

    func testToolActionsAreDescribed() {
        for tool in Catalog.toolActions {
            XCTAssertFalse(tool.title.isEmpty)
            XCTAssertFalse(tool.detail.isEmpty)
        }
    }
}
