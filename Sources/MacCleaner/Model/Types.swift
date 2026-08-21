import Foundation

enum Risk: String, Sendable, Hashable, CaseIterable {
    case safe
    case rebuild
    case protected

    var label: String {
        switch self {
        case .safe: return "SAFE"
        case .rebuild: return "REBUILD"
        case .protected: return "PROTECTED"
        }
    }

    var systemImage: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .rebuild: return "arrow.triangle.2.circlepath"
        case .protected: return "lock.fill"
        }
    }

    var explanation: String {
        switch self {
        case .safe: return "Regenerates automatically. Nothing is lost."
        case .rebuild: return "Regenerates, but you must re-run an install or build first."
        case .protected: return "Real content, not cache. Keep it unless you are certain."
        }
    }
}

enum Category: String, CaseIterable, Identifiable, Sendable {
    case devCaches = "Developer Caches"
    case appJunk = "App Junk"
    case projects = "Project Build Artifacts"
    case tools = "Docker & Toolchains"
    case gitRepos = "Git Repositories"
    case largeFiles = "Large & Old Files"
    case duplicates = "Duplicate Files"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .devCaches: return "hammer"
        case .appJunk: return "trash"
        case .projects: return "shippingbox"
        case .tools: return "cube.transparent"
        case .gitRepos: return "arrow.triangle.branch"
        case .largeFiles: return "doc.viewfinder"
        case .duplicates: return "doc.on.doc"
        }
    }

    var blurb: String {
        switch self {
        case .devCaches: return "Package manager and toolchain caches. Every one of these rebuilds itself on next use."
        case .appJunk: return "Application caches, logs, crash reports, stale installers and backups."
        case .projects: return "node_modules, build output and virtualenvs found inside your project folders."
        case .tools: return "Reclaimable space reported by Docker, Homebrew, SDK managers and the simulator runtime."
        case .gitRepos: return "Repositories carrying loose objects and unreachable history that git gc can pack away."
        case .largeFiles: return "Individual files above a size threshold, or untouched for a long time."
        case .duplicates: return "Byte-identical copies. The newest copy in each set is kept selected-free by default."
        }
    }
}

enum ToolAction: String, Sendable, Hashable {
    case dockerPrune
    case dockerBuilderPrune
    case brewCleanup
    case simctlDeleteUnavailable
    case pnpmStorePrune
    case goCleanModcache
    case gitGarbageCollect
}

struct CleanItem: Identifiable, Sendable, Hashable {
    let id: String
    var title: String
    var detail: String
    var paths: [String]
    var risk: Risk
    var category: Category
    var bytes: Int64
    var action: ToolAction?
    var modified: Date?
    /// The concrete reason this is safe to remove — what recreates it, and at what cost.
    var rationale: String = ""
    var duplicateSet: String?
    var isPreferredCopy: Bool = false
    var isInformational: Bool = false

    var isEmpty: Bool { bytes <= 0 }
}

struct DiskSnapshot: Sendable, Equatable {
    var total: Int64 = 0
    var free: Int64 = 0

    var used: Int64 { max(0, total - free) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

func formatBytes(_ bytes: Int64) -> String {
    guard bytes > 0 else { return "0 B" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return formatter.string(fromByteCount: bytes)
}

func formatAge(_ date: Date?) -> String {
    guard let date else { return "—" }
    let days = Int(Date().timeIntervalSince(date) / 86_400)
    switch days {
    case ..<1: return "today"
    case 1: return "1 day ago"
    case ..<30: return "\(days) days ago"
    case ..<365: return "\(days / 30) mo ago"
    default: return "\(days / 365) yr ago"
    }
}
