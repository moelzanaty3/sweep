import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var state: AppState
    let open: (Category) -> Void

    @State private var revealed = false

    private var hasResults: Bool { state.reclaimableTotal > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                grid
            }
            .padding(26)
        }
        .onAppear {
            withAnimation(Motion.panel.delay(0.05)) { revealed = true }
        }
    }

    // MARK: - Header

    /// One statement, not a dashboard: how much is reclaimable, how much of it is risk-free,
    /// and the single action that acts on it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 32) {
                figure
                Spacer(minLength: 16)
                diskContext
                    .frame(width: 230)
                    .opacity(revealed ? 1 : 0)
            }

            if hasResults { split }

            actions
        }
        .card(padding: 22)
    }

    private var figure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Reclaimable")
                .uiFont(12, .medium)
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)

            Text(hasResults ? formatBytes(state.reclaimableTotal) : "—")
                .uiFont(60, .bold, relativeTo: .largeTitle)
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 2)

            // The one flourish, kept off the number itself so it reads as a product signature
            // rather than decoration on the data.
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.signature)
                .frame(width: 64, height: 3)
                .padding(.top, 8)
                .opacity(hasResults ? 1 : 0.4)

            Text(hasResults
                 ? "\(state.allItems.count) items across \(state.scannedCategories.count) categories"
                 : "Run a scan to see what your tools are holding on to")
                .uiFont(12)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 10)
        }
    }

    private var diskContext: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(formatBytes(state.disk.free))
                    .uiFont(17, .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                Text("free")
                    .uiFont(12)
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.strokeStrong)
                    Capsule()
                        .fill(state.disk.usedFraction > 0.9 ? Theme.danger : Theme.textPrimary)
                        .frame(width: max(3, geo.size.width * state.disk.usedFraction))
                }
            }
            .frame(height: 6)

            Text("\(Int(state.disk.usedFraction * 100))% of \(formatBytes(state.disk.total)) used")
                .uiFont(11, design: .monospaced)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    /// The actual decision: what is free to delete versus what wants a look first.
    private var split: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(Risk.allCases, id: \.self) { risk in
                        let bytes = state.total(forRisk: risk)
                        if bytes > 0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(risk.tint)
                                .frame(width: max(4, geo.size.width * fraction(of: bytes)))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .animation(Motion.panel, value: state.reclaimableTotal)
            }
            .frame(height: 8)

            HStack(spacing: 18) {
                ForEach(Risk.allCases, id: \.self) { risk in
                    let bytes = state.total(forRisk: risk)
                    if bytes > 0 {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2).fill(risk.tint).frame(width: 8, height: 8)
                            Text(formatBytes(bytes))
                                .uiFont(12, .semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Text(caption(for: risk))
                                .uiFont(12)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func caption(for risk: Risk) -> String {
        switch risk {
        case .safe: return "regenerates itself"
        case .rebuild: return "needs a rebuild"
        case .protected: return "needs review"
        }
    }

    private func fraction(of bytes: Int64) -> Double {
        guard state.reclaimableTotal > 0 else { return 0 }
        return Double(bytes) / Double(state.reclaimableTotal)
    }

    private var actions: some View {
        HStack(spacing: 9) {
            Button {
                state.scanAll()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: state.isScanning ? "circle.dotted" : "arrow.clockwise")
                        .rotationEffect(.degrees(state.isScanning ? 360 : 0))
                        .animation(state.isScanning
                                   ? .linear(duration: 1.6).repeatForever(autoreverses: false)
                                   : .default,
                                   value: state.isScanning)
                    Text(state.isScanning ? "Scanning…" : (hasResults ? "Rescan" : "Scan Everything"))
                }
                .fixedSize()
            }
            .buttonStyle(SecondaryButtonStyle())
            .shimmer(active: state.isScanning)
            .disabled(state.isScanning)

            Button {
                state.scanSafeCategories()
            } label: {
                Label("Quick Scan", systemImage: "bolt.fill").fixedSize()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(state.isScanning)
            .help("Caches and tool reclaim only — skips the slow filesystem walks.")

            Spacer(minLength: 12)

            if hasResults {
                Button {
                    withAnimation(Motion.snap) { state.toggleSafeSelection() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: state.hasSelection ? "xmark.circle" : "checkmark.circle")
                        Text(state.hasSelection
                             ? "Clear selection"
                             : "Select \(formatBytes(state.safeTotal)) safe")
                    }
                    .fixedSize()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .help(state.hasSelection
                      ? "Deselect everything (⇧⌘A)"
                      : "Select every item that regenerates on its own (⇧⌘A)")
                .transition(.opacity)
            }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 232), spacing: 14)], spacing: 14) {
            ForEach(Array(Category.allCases.enumerated()), id: \.element) { index, category in
                SectionCard(
                    category: category,
                    bytes: state.total(in: category),
                    count: state.items(in: category).count,
                    scanning: state.scanning.contains(category)
                ) {
                    open(category)
                }
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 10)
                .animation(Motion.panel.delay(Double(index) * 0.035), value: revealed)
            }
        }
    }
}
