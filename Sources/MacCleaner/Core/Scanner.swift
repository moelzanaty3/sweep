import Foundation

enum DiskScanner {
    // MARK: - Catalogued paths

    static func scanSpecs(_ specs: [PathSpec]) async -> [CleanItem] {
        await withTaskGroup(of: CleanItem?.self) { group in
            for spec in specs {
                group.addTask {
                    let existing = spec.absolutePaths.filter { FileManager.default.fileExists(atPath: $0) }
                    guard !existing.isEmpty else { return nil }
                    let bytes = existing.reduce(Int64(0)) { $0 + Shell.size(ofPath: $1) }
                    guard bytes > 0 else { return nil }
                    return CleanItem(
                        id: spec.id,
                        title: spec.title,
                        detail: spec.detail,
                        paths: existing,
                        risk: spec.risk,
                        category: spec.category,
                        bytes: bytes,
                        action: spec.action,
                        modified: existing.compactMap(Shell.modifiedDate).max(),
                        rationale: Catalog.rationale(for: spec.id, risk: spec.risk)
                    )
                }
            }
            var out: [CleanItem] = []
            for await item in group { if let item { out.append(item) } }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    // MARK: - Generic ~/Library/Caches sweep

    static func scanLooseCaches(minimumBytes: Int64 = 5 * 1024 * 1024) async -> [CleanItem] {
        let root = NSHomeDirectory() + "/Library/Caches"
        let known = Catalog.explicitCachePaths
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root) else { return [] }

        // macOS's own cache domains are skipped wholesale: several (Music, AMPLibraryAgent,
        // Photos) are TCC-protected and merely measuring them raises a privacy prompt, and the
        // rest are system-managed, tiny, and not ours to delete. The Apple caches worth
        // reclaiming — Xcode, QuickLook — are named explicitly in the catalog.
        let candidates = names
            .filter { !$0.hasPrefix("com.apple.") }
            .map { "\(root)/\($0)" }
            .filter { !known.contains($0) }

        return await withTaskGroup(of: CleanItem?.self) { group in
            for path in candidates {
                group.addTask {
                    let bytes = Shell.size(ofPath: path)
                    guard bytes >= minimumBytes else { return nil }
                    let name = (path as NSString).lastPathComponent
                    return CleanItem(
                        id: "cache:\(path)",
                        title: prettyBundleName(name),
                        detail: name,
                        paths: [path],
                        risk: .safe,
                        category: .appJunk,
                        bytes: bytes,
                        action: nil,
                        modified: Shell.modifiedDate(ofPath: path),
                        rationale: "Cache written by \(prettyBundleName(name)). The app regenerates it on "
                            + "next launch; your settings and data live elsewhere."
                    )
                }
            }
            var out: [CleanItem] = []
            for await item in group { if let item { out.append(item) } }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    /// "com.microsoft.VSCode" reads better as "VSCode" in a list of forty rows.
    private static func prettyBundleName(_ raw: String) -> String {
        let parts = raw.split(separator: ".")
        guard parts.count >= 3, parts[0] == "com" || parts[0] == "org" || parts[0] == "net" else { return raw }
        return parts.dropFirst(2).joined(separator: ".")
    }

    // MARK: - Project build artifacts

    static func scanProjects(roots: [String], names: [String] = Catalog.projectArtifactNames) async -> [CleanItem] {
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingRoots.isEmpty else { return [] }

        var findArgs = existingRoots
        findArgs += ["-maxdepth", "7", "-type", "d", "("]
        for (index, name) in names.enumerated() {
            if index > 0 { findArgs.append("-o") }
            findArgs += ["-name", name]
        }
        findArgs += [")", "-prune", "-print"]

        let result = Shell.run("/usr/bin/find", findArgs, timeout: 300)
        let paths = result.out.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        guard !paths.isEmpty else { return [] }

        return await withTaskGroup(of: CleanItem?.self) { group in
            for path in paths {
                group.addTask {
                    let bytes = Shell.size(ofPath: path)
                    guard bytes > 0 else { return nil }
                    let url = URL(fileURLWithPath: path)
                    let artifact = url.lastPathComponent
                    let project = url.deletingLastPathComponent()
                    return CleanItem(
                        id: "proj:\(path)",
                        title: project.lastPathComponent,
                        detail: "\(artifact) — \(abbreviate(project.path))",
                        paths: [path],
                        risk: .rebuild,
                        category: .projects,
                        bytes: bytes,
                        action: nil,
                        modified: Shell.modifiedDate(ofPath: project.path),
                        rationale: rationaleForArtifact(artifact)
                    )
                }
            }
            var out: [CleanItem] = []
            for await item in group { if let item { out.append(item) } }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    // MARK: - Large and old files

    static func scanFiles(roots: [String], minimumMB: Int, olderThanDays: Int?) async -> [CleanItem] {
        let existingRoots = roots.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingRoots.isEmpty else { return [] }

        var args = existingRoots
        args += ["-type", "f", "-size", "+\(minimumMB)M"]
        if let days = olderThanDays { args += ["-mtime", "+\(days)"] }
        for skip in Catalog.projectArtifactNames {
            args += ["-not", "-path", "*/\(skip)/*"]
        }
        for suffix in Catalog.opaqueBundleSuffixes {
            args += ["-not", "-path", "*.\(suffix)/*"]
        }
        args += ["-not", "-path", "*/.git/*", "-exec", "stat", "-f", "%z|%m|%N", "{}", "+"]

        let result = Shell.run("/usr/bin/find", args, timeout: 300)
        var items: [CleanItem] = []
        for line in result.out.split(separator: "\n") {
            let fields = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3,
                  let bytes = Int64(fields[0]),
                  let epoch = TimeInterval(fields[1]) else { continue }
            let path = String(fields[2])
            items.append(CleanItem(
                id: "file:\(path)",
                title: (path as NSString).lastPathComponent,
                detail: abbreviate((path as NSString).deletingLastPathComponent),
                paths: [path],
                risk: .protected,
                category: .largeFiles,
                bytes: bytes,
                action: nil,
                modified: Date(timeIntervalSince1970: epoch),
                rationale: "A file you created or downloaded. Nothing regenerates this — move it to Trash if you are unsure."
            ))
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    private static func rationaleForArtifact(_ name: String) -> String {
        switch name {
        case "node_modules":
            return "Restored by `npm install` / `pnpm install` / `yarn` in this project. "
                + "Your source and lockfile are untouched."
        case ".next", ".nuxt", ".svelte-kit", ".turbo", ".parcel-cache":
            return "Framework build output. Regenerated by the next dev server start or build."
        case "dist", "build", "out": return "Compiled output. Regenerated by the next build."
        case ".venv", "venv": return "Python virtualenv. Recreate with `python -m venv` and reinstall requirements."
        case "__pycache__": return "Compiled Python bytecode. Regenerated automatically on next run."
        case "Pods": return "Restored by `pod install`. Your Podfile and lockfile are untouched."
        case "DerivedData": return "Xcode build products for this project. Rebuilt on the next build."
        case ".gradle": return "Project-local Gradle state. Rebuilt on the next Gradle run."
        case "target": return "Rust/Java build output. Rebuilt by the next `cargo build` or Maven run."
        case ".dart_tool": return "Dart/Flutter tooling state. Rebuilt by `flutter pub get`."
        default: return "Build artifact. Regenerated by this project's next install or build."
        }
    }

    // MARK: - External tools

    static func scanTools() async -> [CleanItem] {
        await withTaskGroup(of: CleanItem?.self) { group in
            for entry in Catalog.toolActions {
                group.addTask {
                    guard let bytes = reclaimable(for: entry.action), bytes > 0 else { return nil }
                    return CleanItem(
                        id: entry.id,
                        title: entry.title,
                        detail: entry.detail,
                        paths: [],
                        risk: entry.risk,
                        category: .tools,
                        bytes: bytes,
                        action: entry.action,
                        modified: nil,
                        rationale: Catalog.rationale(for: entry.id, risk: entry.risk)
                    )
                }
            }
            var out: [CleanItem] = []
            for await item in group { if let item { out.append(item) } }
            if let disk = dockerDiskImage() { out.append(disk) }
            return out.sorted { $0.bytes > $1.bytes }
        }
    }

    /// Docker Desktop's disk image only ever grows. Pruning frees space *inside* it, so the
    /// volume stays full until the image is compacted from Docker Desktop's own settings.
    private static func dockerDiskImage() -> CleanItem? {
        guard let path = Catalog.dockerDiskImagePaths.first else { return nil }
        let bytes = Shell.size(ofPath: path)
        guard bytes > 0 else { return nil }
        return CleanItem(
            id: "dockerraw",
            title: "Docker.raw disk image",
            detail: "Never shrinks on its own — prune above, then Docker Desktop → Settings → Resources → Disk image size",
            paths: [path],
            risk: .protected,
            category: .tools,
            bytes: bytes,
            action: nil,
            modified: Shell.modifiedDate(ofPath: path),
            rationale: Catalog.rationale(for: "dockerraw", risk: .protected),
            isInformational: true
        )
    }

    private static func reclaimable(for action: ToolAction) -> Int64? {
        switch action {
        case .dockerPrune:
            return dockerReclaimable(types: ["Images", "Containers", "Local Volumes"])
        case .dockerBuilderPrune:
            return dockerReclaimable(types: ["Build Cache"])
        case .brewCleanup:
            let result = Shell.run("/usr/bin/env", ["brew", "cleanup", "-s", "-n"], timeout: 120)
            guard result.ok else { return nil }
            return parseTrailingSize(result.out)
        case .simctlDeleteUnavailable:
            return unavailableSimulatorBytes()
        default:
            return nil
        }
    }

    private static func dockerReclaimable(types: Set<String>) -> Int64? {
        let result = Shell.run("/usr/bin/env",
                               ["docker", "system", "df", "--format", "{{.Type}}|{{.Reclaimable}}"],
                               timeout: 60)
        guard result.ok else { return nil }
        var total: Int64 = 0
        for line in result.out.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2, types.contains(String(parts[0])) else { continue }
            total += parseSize(String(parts[1])) ?? 0
        }
        return total
    }

    private static func unavailableSimulatorBytes() -> Int64? {
        let result = Shell.run("/usr/bin/xcrun", ["simctl", "list", "devices", "--json"], timeout: 60)
        guard result.ok, let data = result.out.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let byRuntime = root["devices"] as? [String: [[String: Any]]] else { return nil }

        let deviceRoot = NSHomeDirectory() + "/Library/Developer/CoreSimulator/Devices"
        var total: Int64 = 0
        for (_, devices) in byRuntime {
            for device in devices {
                let available = device["isAvailable"] as? Bool ?? true
                guard !available, let udid = device["udid"] as? String else { continue }
                total += Shell.size(ofPath: "\(deviceRoot)/\(udid)")
            }
        }
        return total
    }

    /// Parses "2.455GB (85%)" or "1.2 MB".
    private static func parseSize(_ raw: String) -> Int64? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?B)"#
        guard let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let token = String(text[match])
        let digits = token.prefix { $0.isNumber || $0 == "." }
        guard let value = Double(digits) else { return nil }
        let unit = token.dropFirst(digits.count).trimmingCharacters(in: .whitespaces).uppercased()
        let multiplier: Double
        switch unit {
        case "KB": multiplier = 1_000
        case "MB": multiplier = 1_000_000
        case "GB": multiplier = 1_000_000_000
        case "TB": multiplier = 1_000_000_000_000
        default: multiplier = 1
        }
        return Int64(value * multiplier)
    }

    private static func parseTrailingSize(_ output: String) -> Int64? {
        guard let line = output.split(separator: "\n").last(where: { $0.lowercased().contains("free") }) else { return nil }
        return parseSize(String(line))
    }

    static func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
