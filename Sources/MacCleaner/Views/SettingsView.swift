import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AboutPane()
                    appearanceCard
                    menuBar
                    schedule
                    allowlist
                    thresholds
                    safety
                }
                .padding(18)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GlyphChip(systemName: "gearshape.fill", tint: Theme.accent, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .uiFont(17, .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("Background scanning, exclusions and scan thresholds")
                    .uiFont(12)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.sidebar.opacity(0.5))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    // MARK: - Background schedule

    private var schedule: some View {
        settingsCard(title: "Background scan", icon: "clock.arrow.2.circlepath", tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Run a quick scan")
                        .uiFont(12)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { state.scanInterval },
                        set: { state.scanInterval = $0 }
                    )) {
                        ForEach(ScanInterval.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .controlSize(.small)
                }

                Toggle(isOn: Binding(
                    get: { state.notifyOnBackgroundScan },
                    set: { state.notifyOnBackgroundScan = $0; if $0 { state.requestNotificationAccess() } }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Notify when new space appears")
                            .uiFont(12)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Only fires when the reclaimable total grew since the last scan")
                            .uiFont(11)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if let last = state.lastScanDate {
                    Text("Last scan \(formatAge(last))")
                        .uiFont(11, design: .monospaced)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        settingsCard(title: "Appearance", icon: "paintbrush", tint: Theme.purple) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Theme")
                        .uiFont(12)
                        .foregroundStyle(Theme.textPrimary)
                    Text("System follows your Mac's light and dark setting")
                        .uiFont(11)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 8)
                SegmentedTabs(
                    options: Appearance.allCases.map { .init(value: $0, label: $0.label, icon: $0.icon) },
                    selection: Binding(get: { state.appearance }, set: { state.appearance = $0 })
                )
            }
        }
    }

    // MARK: - Menu bar & startup

    private var menuBar: some View {
        settingsCard(title: "Menu bar & startup", icon: "menubar.rectangle", tint: Theme.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                switchRow(title: "Show Sweep in the menu bar",
                          detail: "A compact panel with the reclaimable total and a quick scan",
                          isOn: Binding(get: { state.showMenuBarItem },
                                        set: { state.showMenuBarItem = $0 }))

                switchRow(title: "Show the size next to the icon",
                          detail: "Off shows the icon alone",
                          isOn: Binding(get: { state.menuBarShowsSize },
                                        set: { state.menuBarShowsSize = $0 }))
                    .disabled(!state.showMenuBarItem)
                    .opacity(state.showMenuBarItem ? 1 : 0.45)

                Divider().overlay(Theme.stroke)

                switchRow(title: "Open at login",
                          detail: "Sweep starts with your Mac and keeps the menu bar total current",
                          isOn: Binding(get: { state.launchAtLogin },
                                        set: { state.setLaunchAtLogin($0) }))

                if state.launchAtLoginRequiresApproval {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .uiFont(11)
                            .foregroundStyle(Theme.amber)
                        Text("macOS needs you to approve Sweep in Login Items.")
                            .uiFont(11)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 8)
                        Button("Open Login Items") { state.openLoginItemsSettings() }
                            .buttonStyle(SecondaryButtonStyle(compact: true))
                    }
                }

                if let error = state.loginItemError {
                    Text(error)
                        .uiFont(11)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func switchRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .uiFont(12)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .uiFont(11)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    // MARK: - Allowlist

    private var allowlist: some View {
        settingsCard(title: "Never touch these", icon: "hand.raised.fill", tint: Risk.safe.tint) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Allowlisted paths are skipped by Projects, Git, Large Files and Duplicates. Right-click any row to add it here.")
                    .uiFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if state.allowlist.isEmpty {
                    Text("Nothing on the allowlist yet.")
                        .uiFont(12, design: .monospaced)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 4) {
                        ForEach(state.allowlist, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .uiFont(11)
                                    .foregroundStyle(Risk.safe.tint)
                                Text(DiskScanner.abbreviate(path))
                                    .uiFont(12, design: .monospaced)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    state.removeFromAllowlist(path)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .uiFont(12)
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }

                Button {
                    state.addAllowlistFolder()
                } label: {
                    Label("Add folder", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
            }
        }
    }

    // MARK: - Thresholds

    private var thresholds: some View {
        settingsCard(title: "Scan thresholds", icon: "slider.horizontal.3", tint: Category.largeFiles.accent) {
            VStack(alignment: .leading, spacing: 10) {
                row("Large files larger than") {
                    Picker("", selection: Binding(get: { state.minimumFileMB }, set: { state.minimumFileMB = $0 })) {
                        Text("50 MB").tag(50); Text("100 MB").tag(100); Text("200 MB").tag(200)
                        Text("500 MB").tag(500); Text("1 GB").tag(1024)
                    }
                }
                row("Large files untouched for") {
                    Picker("", selection: Binding(get: { state.olderThanDays }, set: { state.olderThanDays = $0 })) {
                        Text("any age").tag(0); Text("30+ days").tag(30); Text("90+ days").tag(90)
                        Text("180+ days").tag(180); Text("1+ year").tag(365)
                    }
                }
                row("Duplicates larger than") {
                    Picker("", selection: Binding(get: { state.duplicateMinimumMB }, set: { state.duplicateMinimumMB = $0 })) {
                        Text("10 MB").tag(10); Text("25 MB").tag(25); Text("50 MB").tag(50)
                        Text("100 MB").tag(100); Text("500 MB").tag(500)
                    }
                }
            }
        }
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .uiFont(12)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            content()
                .labelsHidden()
                .frame(width: 130)
                .controlSize(.small)
        }
    }

    private var safety: some View {
        settingsCard(title: "Safety model", icon: "lock.shield.fill", tint: Risk.rebuild.tint) {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(Risk.allCases), id: \.self) { risk in
                    HStack(alignment: .top, spacing: 8) {
                        RiskBadge(risk: risk)
                        Text(risk.explanation)
                            .uiFont(12)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
                Divider().overlay(Theme.stroke).padding(.vertical, 3)
                Text("Deletion is refused outside your home folder, and for SSH keys, GnuPG, Keychains, "
                     + "Preferences and iCloud Drive regardless of what is selected.")
                    .uiFont(12)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, tint: Color,
                                             @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                GlyphChip(systemName: icon, tint: tint, size: 26)
                Text(title)
                    .uiFont(13, .bold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}
