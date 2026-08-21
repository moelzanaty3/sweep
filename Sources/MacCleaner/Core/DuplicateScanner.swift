import CryptoKit
import Foundation

enum DuplicateScanner {
    /// Three passes, cheapest first: group by size, then by a 64 KB head digest, then by a full
    /// digest. Only the survivors of each pass pay for the next one.
    static func scan(roots: [String], minimumMB: Int, whitelist: Set<String>) async -> [CleanItem] {
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingRoots.isEmpty else { return [] }

        var args = existingRoots
        args += ["-type", "f", "-size", "+\(minimumMB)M"]
        for skip in Catalog.projectArtifactNames {
            args += ["-not", "-path", "*/\(skip)/*"]
        }
        for suffix in Catalog.opaqueBundleSuffixes {
            args += ["-not", "-path", "*.\(suffix)/*"]
        }
        args += ["-not", "-path", "*/.git/*", "-exec", "stat", "-f", "%z|%m|%N", "{}", "+"]

        let output = Shell.run("/usr/bin/find", args, timeout: 300).out

        struct Entry {
            let path: String
            let bytes: Int64
            let modified: Date
        }

        var bySize: [Int64: [Entry]] = [:]
        for line in output.split(separator: "\n") {
            let fields = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3,
                  let bytes = Int64(fields[0]),
                  let epoch = TimeInterval(fields[1]) else { continue }
            let path = String(fields[2])
            guard !whitelist.contains(where: { path.hasPrefix($0) }) else { continue }
            bySize[bytes, default: []].append(Entry(path: path, bytes: bytes, modified: Date(timeIntervalSince1970: epoch)))
        }

        let sizeCandidates = bySize.values.filter { $0.count > 1 }.flatMap { $0 }
        guard !sizeCandidates.isEmpty else { return [] }

        let headDigests = await digest(paths: sizeCandidates.map(\.path), headOnly: true)
        var byHead: [String: [Entry]] = [:]
        for entry in sizeCandidates {
            guard let head = headDigests[entry.path] else { continue }
            byHead["\(entry.bytes)-\(head)", default: []].append(entry)
        }

        let headCandidates = byHead.values.filter { $0.count > 1 }.flatMap { $0 }
        guard !headCandidates.isEmpty else { return [] }

        let fullDigests = await digest(paths: headCandidates.map(\.path), headOnly: false)
        var byFull: [String: [Entry]] = [:]
        for entry in headCandidates {
            guard let full = fullDigests[entry.path] else { continue }
            byFull[full, default: []].append(entry)
        }

        var items: [CleanItem] = []
        for (digest, group) in byFull where group.count > 1 {
            // Newest first, so the copy at index 0 is the one worth keeping.
            let ordered = group.sorted { $0.modified > $1.modified }
            let short = String(digest.prefix(7))
            for (index, entry) in ordered.enumerated() {
                items.append(CleanItem(
                    id: "dup:\(entry.path)",
                    title: (entry.path as NSString).lastPathComponent,
                    detail: index == 0
                        ? "newest of \(ordered.count) copies · set \(short) · \(DiskScanner.abbreviate((entry.path as NSString).deletingLastPathComponent))"
                        : "copy \(index + 1) of \(ordered.count) · set \(short) · \(DiskScanner.abbreviate((entry.path as NSString).deletingLastPathComponent))",
                    paths: [entry.path],
                    risk: .protected,
                    category: .duplicates,
                    bytes: entry.bytes,
                    action: nil,
                    modified: entry.modified,
                    rationale: index == 0
                        ? "The most recently modified copy in this set — kept out of Select All so one copy always survives."
                        : "Byte-identical to the newest copy (verified by full SHA-256, not just size).",
                    duplicateSet: short,
                    isPreferredCopy: index == 0
                ))
            }
        }

        return items.sorted {
            $0.duplicateSet == $1.duplicateSet ? !$0.isPreferredCopy && $1.isPreferredCopy : $0.bytes > $1.bytes
        }
    }

    private static func digest(paths: [String], headOnly: Bool) async -> [String: String] {
        await withTaskGroup(of: (String, String?).self) { group in
            for path in paths {
                group.addTask { (path, hash(path: path, headOnly: headOnly)) }
            }
            var result: [String: String] = [:]
            for await (path, value) in group {
                if let value { result[path] = value }
            }
            return result
        }
    }

    private static func hash(path: String, headOnly: Bool) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        if headOnly {
            guard let chunk = try? handle.read(upToCount: 64 * 1024) else { return nil }
            hasher.update(data: chunk)
        } else {
            while let chunk = try? handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
