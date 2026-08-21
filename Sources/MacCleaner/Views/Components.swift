import SwiftUI

// MARK: - Rows

struct ItemRow: View {
    let item: CleanItem
    let isSelected: Bool
    let fraction: Double
    let toggle: () -> Void
    let reveal: () -> Void
    let whitelist: () -> Void

    @State private var hovering = false
    @State private var showingWhy = false

    var body: some View {
        HStack(spacing: 12) {
            if item.isInformational {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 18)
            } else {
                Toggle("", isOn: Binding(get: { isSelected }, set: { _ in toggle() }))
                    .labelsHidden()
                    .toggleStyle(CheckToggleStyle(tint: item.category.accent))
            }

            GlyphChip(systemName: item.category.systemImage, tint: item.category.accent, size: 26)
                .opacity(item.isInformational ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .uiFont(13, .semibold)
                        .foregroundStyle(Theme.textPrimary)
                    if item.isPreferredCopy {
                        Text("KEEP")
                            .uiFont(10, .heavy, design: .default)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Risk.safe.tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(Risk.safe.tint)
                    }
                }
                Text(item.detail)
                    .uiFont(12)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let modified = item.modified {
                Text(formatAge(modified))
                    .uiFont(11, design: .monospaced)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 74, alignment: .trailing)
            }

            RiskBadge(risk: item.risk)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatBytes(item.bytes))
                    .uiFont(12, .bold, design: .default)
                    .foregroundStyle(Theme.textPrimary)
                Capsule()
                    .fill(item.category.accent.opacity(0.85))
                    .frame(width: max(3, 64 * fraction), height: 3)
                    .frame(width: 64, alignment: .trailing)
            }
            .frame(width: 74, alignment: .trailing)

            HStack(spacing: 4) {
                Button { showingWhy = true } label: {
                    Image(systemName: "questionmark.circle")
                        .uiFont(13)
                        .foregroundStyle(showingWhy ? Theme.accent : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Why is this \(item.risk.label.lowercased())?")
                .popover(isPresented: $showingWhy, arrowEdge: .bottom) {
                    WhyPopover(item: item)
                }

                Button(action: reveal) {
                    Image(systemName: "arrow.up.forward.square")
                        .uiFont(13)
                        .foregroundStyle(hovering ? Theme.accent : Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(item.paths.isEmpty)
                .help(item.paths.first.map { DiskScanner.abbreviate($0) } ?? "Runs a tool command")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? item.category.accent.opacity(0.10) : (hovering ? Theme.surfaceRaised : Color.clear))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? item.category.accent.opacity(0.45) : .clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if !item.isInformational { toggle() } }
        .contextMenu {
            Button("Reveal in Finder", action: reveal).disabled(item.paths.isEmpty)
            if !item.paths.isEmpty {
                Button("Never show this again", action: whitelist)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Misc

struct SectionCard: View {
    let category: Category
    let bytes: Int64
    let count: Int
    let scanning: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GlyphChip(systemName: category.systemImage, tint: category.accent, size: 30)
                    Spacer()
                    if scanning {
                        ProgressView().controlSize(.small)
                    } else if count > 0 {
                        Text("Review")
                            .uiFont(11, .medium)
                            .foregroundStyle(hovering ? Theme.textPrimary : Theme.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(hovering ? Theme.surfaceRaised : .clear,
                                        in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(hovering ? Theme.strokeStrong : .clear, lineWidth: 1)
                            }
                    }
                }

                Text(category.rawValue)
                    .uiFont(12, .medium)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(count > 0 ? formatBytes(bytes) : "—")
                    .uiFont(26, .bold, relativeTo: .title)
                    .foregroundStyle(count > 0 ? Theme.textPrimary : Theme.textTertiary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(Theme.strokeStrong)
                        .frame(height: 3)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(category.accent)
                                    .frame(width: geo.size.width * fillFraction, height: 3)
                            }
                        }
                    Text(scanning ? "scanning" : (count > 0 ? "\(count) items" : "not scanned"))
                        .uiFont(11)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(hovering ? Theme.strokeStrong : .clear, lineWidth: 1)
            }
            .offset(y: hovering ? -2 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }

    /// Relative weight inside the card, capped so a single huge category still reads.
    private var fillFraction: Double {
        guard bytes > 0 else { return 0 }
        return min(1, max(0.08, Double(bytes) / Double(20 * 1024 * 1024 * 1024)))
    }
}

struct EmptyState: View {
    let category: Category
    let isScanning: Bool
    let scan: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.accent.opacity(0.10))
                    .frame(width: 78, height: 78)
                Image(systemName: isScanning ? "hourglass" : category.systemImage)
                    .uiFont(30, .light)
                    .foregroundStyle(category.accent)
            }
            .overlay {
                if isScanning {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(category.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(spin))
                        .task {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spin = 360 }
                        }
                }
            }

            Text(isScanning ? "Scanning…" : "Nothing found here")
                .uiFont(15, .semibold)
                .foregroundStyle(Theme.textPrimary)

            Text(category.blurb)
                .uiFont(12)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if !isScanning {
                Button("Scan \(category.rawValue)", action: scan)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var spin: Double = 0
}

struct PathChip: View {
    let path: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.fill")
                .uiFont(11)
                .foregroundStyle(Theme.textTertiary)
            Text(DiskScanner.abbreviate(path))
                .uiFont(11, design: .monospaced)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .uiFont(10, .bold)
                    .foregroundStyle(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.surfaceRaised, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.stroke, lineWidth: 1) }
    }
}


/// The product's differentiator: never assert that something is safe without saying why.
struct WhyPopover: View {
    let item: CleanItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RiskBadge(risk: item.risk)
                Text(item.title)
                    .uiFont(13, .bold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 12)
                Text(formatBytes(item.bytes))
                    .uiFont(13, .bold, design: .default)
                    .foregroundStyle(item.category.accent)
            }

            if !item.rationale.isEmpty {
                Text(item.rationale)
                    .uiFont(12)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !item.paths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.paths.count == 1 ? "Location" : "Locations")
                        .uiFont(11, .heavy)
                        .tracking(0.8)
                        .foregroundStyle(Theme.textTertiary)
                    ForEach(item.paths, id: \.self) { path in
                        Text(DiskScanner.abbreviate(path))
                            .uiFont(11, design: .monospaced)
                            .foregroundStyle(Theme.textSecondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 7))
            }

            Text(item.risk.explanation)
                .uiFont(11)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .frame(width: 340)
        .background(Theme.canvas)
    }
}
