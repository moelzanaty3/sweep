import Foundation

enum CLI {
    static func run(arguments: [String]) {
        let wantsAll = arguments.contains("--all")
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            let disk = DiskInfo.snapshot()
            print("\(Brand.name) — \(formatBytes(disk.free)) free of \(formatBytes(disk.total)) (\(Int(disk.usedFraction * 100))% used)\n")

            var grandTotal: Int64 = 0

            async let devCaches = DiskScanner.scanSpecs(Catalog.devCaches)
            async let appCatalogued = DiskScanner.scanSpecs(Catalog.appJunk)
            async let appLoose = DiskScanner.scanLooseCaches()
            async let tools = DiskScanner.scanTools()

            grandTotal += report(Category.devCaches, await devCaches)
            grandTotal += report(Category.appJunk, (await appCatalogued + (await appLoose)).sorted { $0.bytes > $1.bytes })
            grandTotal += report(Category.tools, await tools)

            if wantsAll {
                let roots = Catalog.defaultScanRoots
                grandTotal += report(Category.projects, await DiskScanner.scanProjects(roots: roots))
                grandTotal += report(Category.gitRepos, await GitScanner.scan(roots: roots))
                grandTotal += report(Category.largeFiles,
                                     await DiskScanner.scanFiles(roots: Catalog.defaultFileRoots,
                                                             minimumMB: 200, olderThanDays: nil))
                grandTotal += report(Category.duplicates,
                                     await DuplicateScanner.scan(roots: Catalog.defaultFileRoots,
                                                                 minimumMB: 50, allowlist: []))
            } else {
                print("(pass --all to also walk projects, git repos and large files)\n")
            }

            print(String(repeating: "─", count: 62))
            print("TOTAL RECLAIMABLE  \(formatBytes(grandTotal))")
            semaphore.signal()
        }

        semaphore.wait()
        exit(0)
    }

    @discardableResult
    private static func report(_ category: Category, _ items: [CleanItem]) -> Int64 {
        let total = items.reduce(Int64(0)) { $0 + $1.bytes }
        guard !items.isEmpty else { return 0 }

        print("\(category.rawValue.uppercased())  —  \(formatBytes(total))")
        for item in items.prefix(30) {
            let size = formatBytes(item.bytes).padding(toLength: 10, withPad: " ", startingAt: 0)
            let risk = item.risk.label.padding(toLength: 8, withPad: " ", startingAt: 0)
            print("  \(size) \(risk) \(item.title)")
        }
        if items.count > 30 { print("  … and \(items.count - 30) more") }
        print("")
        return total
    }
}
