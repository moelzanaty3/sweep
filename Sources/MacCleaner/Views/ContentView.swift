import SwiftUI

enum Panel: Hashable {
    case overview
    case category(Category)
    case activity
    case settings
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var panel: Panel = .overview
    @State private var confirming = false
    @AppStorage("sidebarCollapsed") private var collapsed = false

    private var sidebarWidth: CGFloat { collapsed ? 64 : 250 }

    var body: some View {
        ZStack {
            // A .background() sizes itself to the content, which leaves the window transparent
            // whenever the content is shorter than the frame. A filling ZStack layer does not.
            Theme.canvas.ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Theme.stroke).frame(width: 1)
                VStack(spacing: 0) {
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    actionBar
                }
            }
        }
        .frame(minWidth: 940, minHeight: 660)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(state.appearance.colorScheme)
        .confirmationDialog(confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button(confirmVerb, role: state.disposal == .delete ? .destructive : nil) {
                state.cleanSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader

            navButton(.overview, title: "Overview", icon: "square.grid.2x2", tint: Theme.textPrimary)

            if collapsed {
                Divider().overlay(Theme.stroke).padding(.horizontal, 14).padding(.vertical, 10)
            } else {
                Text("SCAN")
                    .uiFont(10, .heavy)
                    .tracking(1)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
            }

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Category.allCases) { category in
                        navButton(.category(category),
                                  title: category.rawValue,
                                  icon: category.systemImage,
                                  tint: category.accent,
                                  trailing: trailingLabel(for: category),
                                  busy: state.scanning.contains(category))
                    }
                }
            }
            .scrollIndicators(.never)

            Spacer(minLength: 8)

            Divider().overlay(Theme.stroke).padding(.vertical, 8)

            navButton(.activity, title: "Activity", icon: "list.bullet.rectangle", tint: Theme.textSecondary)
            navButton(.settings, title: "Settings", icon: "gearshape", tint: Theme.textSecondary)

            if collapsed { collapsedFooter } else { diskFooter }
        }
        .frame(width: sidebarWidth)
        .background(Theme.sidebar)
        .animation(Motion.panel, value: collapsed)
    }

    private var brandHeader: some View {
        Group {
            if collapsed { collapsedHeader } else { expandedHeader }
        }
        .padding(.top, 30)
        .padding(.bottom, 16)
        .background {
            // Keyboard-only affordance. opacity(0) still hit-tests in SwiftUI, so it must be
            // taken out of the pointer chain or it swallows clicks meant for the header.
            Button("") { withAnimation(Motion.panel) { collapsed.toggle() } }
                .keyboardShortcut("\\", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    private var collapsedHeader: some View {
        VStack(spacing: 10) {
            SweepMark(size: 28)

            Button {
                withAnimation(Motion.panel) { collapsed = false }
            } label: {
                Image(systemName: "sidebar.leading")
                    .uiFont(12, .medium)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Expand sidebar (⌘\\)")
        }
        .frame(maxWidth: .infinity)
    }

    private var expandedHeader: some View {
        HStack(spacing: 9) {
            SweepMark(size: 28)

            if true {
                VStack(alignment: .leading, spacing: -1) {
                    Text(Brand.name)
                        .uiFont(15, .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(Brand.tagline)
                        .uiFont(11)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(Motion.panel) { collapsed.toggle() }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .uiFont(12, .medium)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Collapse sidebar (⌘\\)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }

    private func trailingLabel(for category: Category) -> String? {
        let total = state.total(in: category)
        return total > 0 ? formatBytes(total) : nil
    }

    private func navButton(_ target: Panel, title: String, icon: String, tint: Color,
                           trailing: String? = nil, busy: Bool = false) -> some View {
        let active = panel == target

        return Button {
            withAnimation(Motion.quick) { panel = target }
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    Image(systemName: icon)
                        .uiFont(13, .medium)
                        .foregroundStyle(active ? tint : Theme.textTertiary)
                    // A collapsed rail still has to signal that a category found something.
                    if collapsed, trailing != nil, !busy {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                            .offset(x: 9, y: -8)
                    }
                }
                .frame(width: 18)

                if !collapsed {
                    Text(title)
                        .uiFont(13, active ? .semibold : .regular)
                        .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if busy {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else if let trailing {
                        Text(trailing)
                            .uiFont(11, .medium, design: .monospaced)
                            .foregroundStyle(tint.opacity(0.9))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .padding(.horizontal, collapsed ? 0 : 10)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? Theme.surfaceRaised : .clear)
            }
            .overlay(alignment: .leading) {
                if active {
                    Capsule().fill(tint).frame(width: 2, height: 14).offset(x: collapsed ? -4 : -3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .help(collapsed ? title : "")
    }

    private var diskFooter: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(formatBytes(state.disk.free))
                    .uiFont(13, .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("free")
                    .uiFont(11)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("\(Int(state.disk.usedFraction * 100))%")
                    .uiFont(11, design: .monospaced)
                    .foregroundStyle(state.disk.usedFraction > 0.9 ? Theme.danger : Theme.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.strokeStrong)
                    Capsule()
                        .fill(state.disk.usedFraction > 0.9 ? Theme.danger : Theme.textPrimary)
                        .frame(width: max(3, geo.size.width * state.disk.usedFraction))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var collapsedFooter: some View {
        VStack(spacing: 5) {
            Text("\(Int(state.disk.usedFraction * 100))%")
                .uiFont(10, .semibold, design: .monospaced)
                .foregroundStyle(state.disk.usedFraction > 0.9 ? Theme.danger : Theme.textTertiary)
            Capsule()
                .fill(Theme.strokeStrong)
                .frame(width: 26, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.textPrimary)
                        .frame(width: max(2, 26 * state.disk.usedFraction), height: 3)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .help("\(formatBytes(state.disk.free)) free")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch panel {
        case .category(let category): CategoryView(category: category)
        case .activity: ActivityView()
        case .settings: SettingsView()
        case .overview: OverviewView { category in
            withAnimation(Motion.quick) { panel = .category(category) }
        }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(state.isScanning ? Theme.accent : (state.cleaning ? Theme.amber : Theme.green))
                .frame(width: 6, height: 6)
                .opacity(state.isScanning || state.cleaning ? 1 : 0.55)

            Text(state.statusLine)
                .uiFont(12)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            SegmentedTabs(
                options: [
                    .init(value: Cleaner.Disposal.trash, label: "Trash", icon: "trash"),
                    .init(value: Cleaner.Disposal.delete, label: "Delete", icon: "xmark.bin")
                ],
                selection: Binding(get: { state.disposal }, set: { state.disposal = $0 })
            )
            .help("Trash is recoverable but slower on huge caches. Delete is immediate and permanent.")

            if !state.selectedItems.isEmpty {
                HStack(spacing: 5) {
                    Text("\(state.selectedItems.count)")
                        .uiFont(12, .bold)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text("selected")
                        .uiFont(12)
                        .foregroundStyle(Theme.textTertiary)
                    Text(formatBytes(state.selectedBytes))
                        .uiFont(12, .bold)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())

                    Button {
                        withAnimation(Motion.snap) { state.clearSelection() }
                    } label: {
                        Image(systemName: "xmark")
                            .uiFont(10, .bold)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.leading, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear selection (⎋)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.stroke, lineWidth: 1) }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Button {
                confirming = true
            } label: {
                if state.cleaning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Cleaning…")
                    }
                } else {
                    Label(state.disposal == .delete ? "Delete Selected" : "Clean Selected",
                          systemImage: "sparkles")
                        .fixedSize()
                }
            }
            .buttonStyle(PrimaryButtonStyle(destructive: state.disposal == .delete))
            .shimmer(active: state.cleaning)
            .keyboardShortcut(.defaultAction)
            .disabled(state.selectedItems.isEmpty || state.cleaning)
            .opacity(state.selectedItems.isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Theme.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
        .animation(Motion.snap, value: state.selectedItems.count)
    }

    private var confirmTitle: String {
        "\(confirmVerb) \(state.selectedItems.count) item\(state.selectedItems.count == 1 ? "" : "s")?"
    }

    private var confirmVerb: String {
        state.disposal == .trash ? "Move to Trash" : "Delete Permanently"
    }

    private var confirmMessage: String {
        let risky = state.selectedItems.filter { $0.risk != .safe }
        var lines = ["Reclaims about \(formatBytes(state.selectedBytes))."]
        let rebuild = risky.filter { $0.risk == .rebuild }.count
        let data = risky.filter { $0.risk == .protected }.count
        if rebuild > 0 { lines.append("\(rebuild) need a reinstall or rebuild afterwards.") }
        if data > 0 { lines.append("\(data) contain real data, not regenerable cache.") }
        if state.disposal == .delete { lines.append("This cannot be undone.") }
        return lines.joined(separator: " ")
    }
}
