import Foundation

enum GitScanner {
    /// Reclaimable = loose objects plus already-detached garbage. `git gc` packs both away
    /// without touching reachable history.
    static func scan(roots: [String]) async -> [CleanItem] {
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingRoots.isEmpty, Shell.which("git") != nil else { return [] }

        let find = Shell.run("/usr/bin/find",
                             existingRoots + ["-maxdepth", "6", "-type", "d", "-name", ".git", "-prune", "-print"],
                             timeout: 180)
        let gitDirs = find.out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard !gitDirs.isEmpty else { return [] }

        return await withTaskGroup(of: CleanItem?.self) { group in
            for gitDir in gitDirs {
                group.addTask { item(forGitDir: gitDir) }
            }
            var out: [CleanItem] = []
            for await item in group { if let item { out.append(item) } }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    private static func item(forGitDir gitDir: String) -> CleanItem? {
        let repo = (gitDir as NSString).deletingLastPathComponent
        let result = Shell.run("/usr/bin/env",
                               ["git", "-C", repo, "count-objects", "-v"],
                               timeout: 60)
        guard result.ok else { return nil }

        var fields: [String: Int64] = [:]
        for line in result.out.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            fields[String(parts[0])] = Int64(parts[1].trimmingCharacters(in: .whitespaces))
        }

        let looseKB = fields["size"] ?? 0
        let garbageKB = fields["size-garbage"] ?? 0
        let looseCount = fields["count"] ?? 0
        let reclaimable = (looseKB + garbageKB) * 1024
        guard reclaimable > 2 * 1024 * 1024 else { return nil }

        return CleanItem(
            id: "git:\(repo)",
            title: (repo as NSString).lastPathComponent,
            detail: "\(looseCount) loose objects — \(DiskScanner.abbreviate(repo))",
            paths: [repo],
            risk: .safe,
            category: .gitRepos,
            bytes: reclaimable,
            action: .gitGarbageCollect,
            modified: Shell.modifiedDate(ofPath: gitDir),
            rationale: "Runs `git gc --prune=now`, which packs loose objects and drops unreachable ones. "
                + "Reachable history, branches and tags are untouched."
        )
    }
}
