import AppKit
import ServiceManagement
import UserNotifications

/// The boundary between Sweep and the parts of macOS that cannot run
/// unattended: a modal folder picker, the login-item service, Finder and the
/// notification centre.
///
/// Everything here is a one-line call into AppKit or ServiceManagement with no
/// branching of its own. It is deliberately the only place such calls appear,
/// so the rest of the app can be driven by tests through `AppState.System`.
/// This file is excluded from the coverage gate for that reason — executing it
/// would open panels, register real login items and post real notifications.
enum SystemServices {
    static func pickFolders() -> [String]? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.map(\.path)
    }

    static func loginItemStatus() -> SMAppService.Status {
        SMAppService.mainApp.status
    }

    static func setLoginItem(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func deliverNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension AppState {
    /// Swappable handles onto `SystemServices`. Tests replace these; nothing
    /// else should.
    enum System {
        nonisolated(unsafe) static var pickFolders: () -> [String]? = SystemServices.pickFolders
        nonisolated(unsafe) static var loginItemStatus: () -> SMAppService.Status = SystemServices.loginItemStatus
        nonisolated(unsafe) static var setLoginItem: (Bool) throws -> Void = SystemServices.setLoginItem
        nonisolated(unsafe) static var openLoginItemsSettings: () -> Void = SystemServices.openLoginItemsSettings
        nonisolated(unsafe) static var revealInFinder: (String) -> Void = SystemServices.revealInFinder
        nonisolated(unsafe) static var requestNotificationAccess: () -> Void = SystemServices.requestNotificationAccess
        nonisolated(unsafe) static var deliverNotification: (String, String) -> Void = {
            SystemServices.deliverNotification(title: $0, body: $1)
        }

        static func reset() {
            pickFolders = SystemServices.pickFolders
            loginItemStatus = SystemServices.loginItemStatus
            setLoginItem = SystemServices.setLoginItem
            openLoginItemsSettings = SystemServices.openLoginItemsSettings
            revealInFinder = SystemServices.revealInFinder
            requestNotificationAccess = SystemServices.requestNotificationAccess
            deliverNotification = { SystemServices.deliverNotification(title: $0, body: $1) }
        }
    }
}
