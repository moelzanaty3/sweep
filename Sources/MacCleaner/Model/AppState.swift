import AppKit
import Foundation
import ServiceManagement
import SwiftUI
import UserNotifications

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum ScanInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case hourly = 3600
    case sixHourly = 21600
    case daily = 86400
    case weekly = 604800

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .hourly: return "Every hour"
        case .sixHourly: return "Every 6 hours"
        case .daily: return "Every day"
        case .weekly: return "Every week"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var itemsByCategory: [Category: [CleanItem]] = [:]
    @Published var selection: Set<String> = []
    @Published var scanning: Set<Category> = []
    @Published var statusLine = "Ready — run a scan to see what is reclaimable."
    @Published var disk = DiskInfo.snapshot()
    @Published var freedThisSession: Int64 = 0
    @Published var activity: [String] = []
    @Published var cleaning = false
    @Published var lastScanDate: Date?

    // @AppStorage is a View-only DynamicProperty; inside an ObservableObject it silently skips
    // change publication, so preferences are @Published and mirrored to UserDefaults by hand.
    @Published var disposal: Cleaner.Disposal { didSet { store(disposal.rawValue, "disposal") } }
    @Published var projectRoots: [String] { didSet { store(projectRoots.joined(separator: "\n"), "projectRoots") } }
    @Published var fileRoots: [String] { didSet { store(fileRoots.joined(separator: "\n"), "fileRoots") } }
    /// Path prefixes that never surface in Projects, Git, Large Files or Duplicates.
    @Published var allowlist: [String] { didSet { store(allowlist.joined(separator: "\n"), "allowlist") } }
    @Published var minimumFileMB: Int { didSet { store(minimumFileMB, "minimumFileMB") } }
    @Published var olderThanDays: Int { didSet { store(olderThanDays, "olderThanDays") } }
    @Published var duplicateMinimumMB: Int { didSet { store(duplicateMinimumMB, "duplicateMinimumMB") } }
    @Published var notifyOnBackgroundScan: Bool { didSet { store(notifyOnBackgroundScan, "notifyOnBackgroundScan") } }
    @Published var menuBarShowsSize: Bool { didSet { store(menuBarShowsSize, "menuBarShowsSize") } }
    @Published var showMenuBarItem: Bool { didSet { store(showMenuBarItem, "showMenuBarItem") } }
    @Published var appearance: Appearance {
        didSet {
            store(appearance.rawValue, "appearance")
            // @Published + didSet also fires for the assignment in init(), which runs before
            // NSApplication has finished launching; touching NSApp there breaks scene setup.
            if didLoad { applyAppearance() }
        }
    }
    @Published var loginItemError: String?
    @Published var scanInterval: ScanInterval {
        didSet {
            store(scanInterval.rawValue, "scanIntervalSeconds")
            rescheduleTimer()
        }
    }

    private var timer: Timer?
    private var didLoad = false
    private let defaults = UserDefaults.standard

    init() {
        // object(forKey:) + ?? distinguishes "never set" from "set to false"; bool(forKey:)
        // collapses both to false and would silently reset every default on launch.
        let store = defaults
        func int(_ key: String, _ fallback: Int) -> Int { store.object(forKey: key) as? Int ?? fallback }
        func flag(_ key: String, _ fallback: Bool) -> Bool { store.object(forKey: key) as? Bool ?? fallback }

        disposal = Cleaner.Disposal(rawValue: store.string(forKey: "disposal") ?? "") ?? .trash
        minimumFileMB = int("minimumFileMB", 200)
        olderThanDays = int("olderThanDays", 0)
        duplicateMinimumMB = int("duplicateMinimumMB", 50)
        notifyOnBackgroundScan = flag("notifyOnBackgroundScan", true)
        menuBarShowsSize = flag("menuBarShowsSize", true)
        showMenuBarItem = flag("showMenuBarItem", true)
        appearance = Appearance(rawValue: store.string(forKey: "appearance") ?? "") ?? .system
        scanInterval = ScanInterval(rawValue: int("scanIntervalSeconds", 0)) ?? .off

        let storedProjects = Self.decode(defaults.string(forKey: "projectRoots"))
        let storedFiles = Self.decode(defaults.string(forKey: "fileRoots"))
        projectRoots = storedProjects.isEmpty ? Catalog.defaultScanRoots : storedProjects
        fileRoots = storedFiles.isEmpty ? Catalog.defaultFileRoots : storedFiles
        // The key was renamed from "whitelist"; read the old one once so an
        // existing install does not silently lose its exclusions.
        let storedAllowlist = Self.decode(defaults.string(forKey: "allowlist"))
        let legacyAllowlist = Self.decode(defaults.string(forKey: "whitelist"))
        allowlist = storedAllowlist.isEmpty ? legacyAllowlist : storedAllowlist

        didLoad = true
        rescheduleTimer()
    }

    private func store(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private static func decode(_ raw: String?) -> [String] {
        (raw ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - Derived

    func items(in category: Category) -> [CleanItem] { itemsByCategory[category] ?? [] }

    var allItems: [CleanItem] { Category.allCases.flatMap { items(in: $0) } }

    func total(in category: Category) -> Int64 { items(in: category).reduce(0) { $0 + $1.bytes } }

    var selectedItems: [CleanItem] { allItems.filter { selection.contains($0.id) } }

    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }

    var reclaimableTotal: Int64 { allItems.reduce(0) { $0 + $1.bytes } }

    func total(forRisk risk: Risk) -> Int64 {
        allItems.filter { $0.risk == risk }.reduce(0) { $0 + $1.bytes }
    }

    var safeTotal: Int64 { total(forRisk: .safe) }
    var reviewTotal: Int64 { reclaimableTotal - safeTotal }
    var hasSelection: Bool { !selection.isEmpty }

    var isScanning: Bool { !scanning.isEmpty }

    var scannedCategories: [Category] { Category.allCases.filter { !items(in: $0).isEmpty } }

    var menuBarLabel: String {
        guard menuBarShowsSize, reclaimableTotal > 0 else { return "" }
        return formatBytes(reclaimableTotal)
    }

    // MARK: - Selection

    func toggle(_ item: CleanItem) {
        if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
    }

    func selectAll(in category: Category) {
        // Never bulk-select the copy we advise keeping.
        let ids = items(in: category).filter { !$0.isPreferredCopy }.map(\.id)
        selection.formUnion(ids)
    }

    func deselectAll(in category: Category) {
        selection.subtract(items(in: category).map(\.id))
    }

    func selectSafeDefaults() {
        selection = Set(allItems.filter { $0.risk == .safe }.map(\.id))
    }

    func clearSelection() {
        selection.removeAll()
    }

    /// One control for both directions — selecting every safe item with no way back was a dead end.
    func toggleSafeSelection() {
        if hasSelection { clearSelection() } else { selectSafeDefaults() }
    }

    // MARK: - Allowlist

    func addToAllowlist(_ item: CleanItem) {
        guard let path = item.paths.first else { return }
        let project = item.category == .projects
            ? (path as NSString).deletingLastPathComponent
            : path
        guard !allowlist.contains(project) else { return }
        allowlist = (allowlist + [project]).sorted()
        selection.remove(item.id)
        for category in Category.allCases {
            itemsByCategory[category]?.removeAll { $0.paths.first?.hasPrefix(project) == true }
        }
        log("Added \(DiskScanner.abbreviate(project)) to the allowlist")
    }

    func removeFromAllowlist(_ path: String) {
        allowlist = allowlist.filter { $0 != path }
    }

    func addAllowlistFolder() {
        guard let picked = pickFolders() else { return }
        allowlist = Array(Set(allowlist + picked)).sorted()
    }

    // MARK: - Scanning

    func scanAll() {
        for category in Category.allCases { scan(category) }
    }

    func scanSafeCategories() {
        scan(.devCaches)
        scan(.appJunk)
        scan(.tools)
    }

    func scan(_ category: Category) {
        guard !scanning.contains(category) else { return }
        scanning.insert(category)
        statusLine = "Scanning \(category.rawValue)…"

        let projectRoots = self.projectRoots
        let fileRoots = self.fileRoots
        let blocked = Set(self.allowlist)
        let minimumMB = self.minimumFileMB
        let duplicateMB = self.duplicateMinimumMB
        let ageFilter = self.olderThanDays > 0 ? self.olderThanDays : nil

        Task {
            var found: [CleanItem]
            switch category {
            case .devCaches:
                found = await DiskScanner.scanSpecs(Catalog.devCaches)
            case .appJunk:
                async let catalogued = DiskScanner.scanSpecs(Catalog.appJunk)
                async let loose = DiskScanner.scanLooseCaches()
                found = (await catalogued + (await loose)).sorted { $0.bytes > $1.bytes }
            case .projects:
                found = await DiskScanner.scanProjects(roots: projectRoots)
            case .tools:
                found = await DiskScanner.scanTools()
            case .gitRepos:
                found = await GitScanner.scan(roots: projectRoots)
            case .largeFiles:
                found = await DiskScanner.scanFiles(roots: fileRoots, minimumMB: minimumMB, olderThanDays: ageFilter)
            case .duplicates:
                found = await DuplicateScanner.scan(roots: fileRoots, minimumMB: duplicateMB, allowlist: blocked)
            }

            if !blocked.isEmpty {
                found = found.filter { item in
                    guard let path = item.paths.first else { return true }
                    return !blocked.contains { path.hasPrefix($0) }
                }
            }

            let staleIDs = Set(items(in: category).map(\.id)).subtracting(found.map(\.id))
            selection.subtract(staleIDs)
            itemsByCategory[category] = found
            scanning.remove(category)
            disk = DiskInfo.snapshot()
            lastScanDate = Date()
            statusLine = isScanning
                ? "Scanning…"
                : "\(formatBytes(reclaimableTotal)) reclaimable across \(allItems.count) items."
            log("Scanned \(category.rawValue): \(found.count) items, \(formatBytes(found.reduce(0) { $0 + $1.bytes }))")
        }
    }

    // MARK: - Cleaning

    func cleanSelected() {
        let targets = selectedItems
        guard !targets.isEmpty, !cleaning else { return }
        cleaning = true
        let disposal = self.disposal
        log("Cleaning \(targets.count) items via \(disposal.rawValue.lowercased())…")

        Task {
            var freed: Int64 = 0
            var failed = 0

            for (index, item) in targets.enumerated() {
                statusLine = "Cleaning \(index + 1) of \(targets.count): \(item.title)"
                let outcome = await Cleaner.clean(item, disposal: disposal)
                if outcome.succeeded {
                    freed += outcome.freed
                    selection.remove(item.id)
                    itemsByCategory[item.category]?.removeAll { $0.id == item.id }
                } else {
                    failed += 1
                }
                log("\(outcome.succeeded ? "✓" : "✗") \(outcome.title) — \(outcome.message)")
            }

            freedThisSession += freed
            disk = DiskInfo.snapshot()
            cleaning = false
            statusLine = failed == 0
                ? "Freed \(formatBytes(freed))."
                : "Freed \(formatBytes(freed)). \(failed) item\(failed == 1 ? "" : "s") failed — see Activity."
        }
    }

    /// The palette resolves through NSColor appearance providers, so the override has to reach
    /// AppKit — a SwiftUI-only colorScheme would leave the menu bar panel and chrome behind.
    func applyAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    // MARK: - Login item

    /// SMAppService owns the truth here — it survives reinstalls and the user can revoke it from
    /// System Settings, so the toggle reads the live status rather than a stored copy.
    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var launchAtLoginRequiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
            log(enabled ? "Enabled open at login" : "Disabled open at login")
        } catch {
            loginItemError = (error as NSError).localizedDescription
            log("Open at login failed — \((error as NSError).localizedDescription)")
        }
        objectWillChange.send()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Background schedule

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard scanInterval != .off else { return }

        let interval = TimeInterval(scanInterval.rawValue)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.runBackgroundScan() }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        log("Background scan scheduled: \(scanInterval.label.lowercased())")
    }

    private func runBackgroundScan() {
        guard !isScanning, !cleaning else { return }
        let before = reclaimableTotal
        log("Background scan started")
        scanSafeCategories()

        Task {
            while isScanning { try? await Task.sleep(nanoseconds: 500_000_000) }
            guard notifyOnBackgroundScan, reclaimableTotal > before else { return }
            notify(title: "DevSweep found \(formatBytes(reclaimableTotal)) to reclaim",
                   body: "\(allItems.count) items across \(scannedCategories.count) categories.")
        }
    }

    func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Misc

    func reveal(_ item: CleanItem) {
        guard let path = item.paths.first else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func addRoot(toProjects: Bool) {
        guard let picked = pickFolders() else { return }
        if toProjects {
            projectRoots = Array(Set(projectRoots + picked)).sorted()
        } else {
            fileRoots = Array(Set(fileRoots + picked)).sorted()
        }
    }

    func removeRoot(_ path: String, fromProjects: Bool) {
        if fromProjects {
            projectRoots = projectRoots.filter { $0 != path }
        } else {
            fileRoots = fileRoots.filter { $0 != path }
        }
    }

    private func pickFolders() -> [String]? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.map(\.path)
    }

    func log(_ line: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        activity.insert("[\(stamp)] \(line)", at: 0)
        if activity.count > 400 { activity.removeLast(activity.count - 400) }
    }
}
