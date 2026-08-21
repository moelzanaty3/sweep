import AppKit
import Foundation

struct CleanOutcome: Sendable {
    var itemID: String
    var title: String
    var freed: Int64
    var message: String
    var succeeded: Bool
}

enum Cleaner {
    /// Seam for tests. The tool actions shell out to docker, brew, go and git;
    /// running those for real would mutate the machine the suite is running on,
    /// so tests install a stub and assert on how its result is interpreted.
    nonisolated(unsafe) static var runner: ((String, [String], TimeInterval) -> ShellResult)?

    private static func execute(_ path: String, _ args: [String], _ timeout: TimeInterval) -> ShellResult {
        if let runner { return runner(path, args, timeout) }
        return Shell.run(path, args, timeout: timeout)
    }
    enum Disposal: String, CaseIterable, Identifiable {
        case trash = "Move to Trash"
        case delete = "Delete immediately"
        var id: String { rawValue }
    }

    static func clean(_ item: CleanItem, disposal: Disposal) async -> CleanOutcome {
        if let action = item.action, shouldUseAction(action, for: item, disposal: disposal) {
            return runAction(action, for: item)
        }
        return removePaths(of: item, disposal: disposal)
    }

    /// Tool-driven items have no path to trash, so their command always wins. Path items that
    /// merely *prefer* a command (pnpm, go) fall back to plain removal when the user picked Trash.
    private static func shouldUseAction(_ action: ToolAction, for item: CleanItem, disposal: Disposal) -> Bool {
        if item.paths.isEmpty { return true }
        return disposal == .delete
    }

    private static func runAction(_ action: ToolAction, for item: CleanItem) -> CleanOutcome {
        let result: ShellResult
        switch action {
        case .dockerPrune:
            result = execute("/usr/bin/env", ["docker", "system", "prune", "-af"], 600)
        case .dockerBuilderPrune:
            result = execute("/usr/bin/env", ["docker", "builder", "prune", "-af"], 600)
        case .brewCleanup:
            result = execute("/usr/bin/env", ["brew", "cleanup", "-s"], 600)
        case .simctlDeleteUnavailable:
            result = execute("/usr/bin/xcrun", ["simctl", "delete", "unavailable"], 600)
        case .pnpmStorePrune:
            result = execute("/usr/bin/env", ["pnpm", "store", "prune"], 600)
        case .goCleanModcache:
            result = execute("/usr/bin/env", ["go", "clean", "-modcache"], 600)
        case .gitGarbageCollect:
            guard let repo = item.paths.first else {
                return CleanOutcome(itemID: item.id, title: item.title, freed: 0,
                                    message: "no repository path", succeeded: false)
            }
            result = execute("/usr/bin/env", ["git", "-C", repo, "gc", "--prune=now", "--quiet"], 900)
        }

        guard result.ok else {
            let reason = result.status == 127 ? "tool not installed" : firstLine(result.out)
            return CleanOutcome(itemID: item.id, title: item.title, freed: 0,
                                message: reason.isEmpty ? "exit \(result.status)" : reason,
                                succeeded: false)
        }
        return CleanOutcome(itemID: item.id, title: item.title, freed: item.bytes,
                            message: "reclaimed \(formatBytes(item.bytes))", succeeded: true)
    }

    private static func removePaths(of item: CleanItem, disposal: Disposal) -> CleanOutcome {
        var freed: Int64 = 0
        var failures: [String] = []

        for path in item.paths {
            guard isRemovable(path) else {
                failures.append("refused \(DiskScanner.abbreviate(path))")
                continue
            }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let before = Shell.size(ofPath: path)

            switch disposal {
            case .trash:
                do {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    freed += before
                } catch {
                    failures.append(shortError(error, path: path))
                }
            case .delete:
                let result = execute("/bin/rm", ["-rf", path], 900)
                if result.ok {
                    freed += before
                } else {
                    failures.append(firstLine(result.out))
                }
            }
        }

        let succeeded = failures.isEmpty
        return CleanOutcome(
            itemID: item.id,
            title: item.title,
            freed: freed,
            message: succeeded ? "freed \(formatBytes(freed))" : failures.joined(separator: "; "),
            succeeded: succeeded
        )
    }

    /// Nothing outside the home directory, and never the home directory itself or a direct
    /// child of it that we did not put in the catalog.
    static func isRemovable(_ path: String) -> Bool {
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path
        let target = URL(fileURLWithPath: path).standardizedFileURL.path

        guard target.hasPrefix(home + "/") else { return false }
        guard !target.contains("/..") else { return false }

        let relative = target.dropFirst(home.count + 1)
        let depth = relative.split(separator: "/").count
        guard depth >= 2 || Catalog.explicitCachePaths.contains(target) else { return false }

        let protected = ["/Library/Keychains", "/Library/Preferences", "/.ssh", "/.gnupg",
                         "/Library/Application Support/com.apple", "/Library/Mobile Documents"]
        return !protected.contains { target.hasPrefix(home + $0) }
    }

    private static func firstLine(_ text: String) -> String {
        text.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private static func shortError(_ error: Error, path: String) -> String {
        "\((error as NSError).localizedDescription) — \(DiskScanner.abbreviate(path))"
    }
}
