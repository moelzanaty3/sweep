import SwiftUI

struct CategoryView: View {
    let category: Category
    @EnvironmentObject var state: AppState
    private var items: [CleanItem] { state.items(in: category) }
    private var largest: Int64 { items.map(\.bytes).max() ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            if items.isEmpty {
                EmptyState(category: category, isScanning: state.scanning.contains(category)) {
                    state.scan(category)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(items) { item in
                            ItemRow(
                                item: item,
                                isSelected: state.selection.contains(item.id),
                                fraction: Double(item.bytes) / Double(max(1, largest)),
                                toggle: { state.toggle(item) },
                                reveal: { state.reveal(item) },
                                whitelist: { state.addToWhitelist(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                GlyphChip(systemName: category.systemImage, tint: category.accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .uiFont(17, .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(category.blurb)
                        .uiFont(12)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if state.scanning.contains(category) {
                    ProgressView().controlSize(.small)
                }

                Button {
                    state.scan(category)
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .disabled(state.scanning.contains(category))
            }

            if needsOptions { options }

            HStack(spacing: 8) {
                Button("Select all") { state.selectAll(in: category) }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                Button("Clear") { state.deselectAll(in: category) }
                    .buttonStyle(SecondaryButtonStyle(compact: true))

                Spacer()

                Text("\(items.count) items")
                    .uiFont(11, design: .monospaced)
                    .foregroundStyle(Theme.textTertiary)
                Text(formatBytes(state.total(in: category)))
                    .uiFont(12, .bold, design: .default)
                    .foregroundStyle(category.accent)
            }
        }
        .padding(16)
        .background(Theme.sidebar.opacity(0.5))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    private var needsOptions: Bool {
        [.largeFiles, .projects, .gitRepos, .duplicates].contains(category)
    }

    @ViewBuilder
    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if category == .largeFiles {
                    labeledPicker("Larger than", selection: $state.minimumFileMB, options: [
                        (50, "50 MB"), (100, "100 MB"), (200, "200 MB"), (500, "500 MB"), (1024, "1 GB")
                    ])
                    labeledPicker("Untouched", selection: $state.olderThanDays, options: [
                        (0, "any age"), (30, "30+ days"), (90, "90+ days"), (180, "180+ days"), (365, "1+ year")
                    ])
                }

                if category == .duplicates {
                    labeledPicker("Larger than", selection: $state.duplicateMinimumMB, options: [
                        (10, "10 MB"), (25, "25 MB"), (50, "50 MB"), (100, "100 MB"), (500, "500 MB")
                    ])
                }

                Button {
                    state.addRoot(toProjects: usesProjectRoots)
                } label: {
                    Label("Add folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(roots, id: \.self) { root in
                        PathChip(path: root) { state.removeRoot(root, fromProjects: usesProjectRoots) }
                    }
                }
            }
        }
    }

    private func labeledPicker(_ title: String, selection: Binding<Int>, options: [(Int, String)]) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .uiFont(11, .medium)
                .foregroundStyle(Theme.textTertiary)
            Picker("", selection: selection) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }
            .labelsHidden()
            .frame(width: 104)
            .controlSize(.small)
        }
    }

    private var usesProjectRoots: Bool {
        category == .projects || category == .gitRepos
    }

    private var roots: [String] {
        usesProjectRoots ? state.projectRoots : state.fileRoots
    }
}

struct ActivityView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                GlyphChip(systemName: "list.bullet.rectangle", tint: Theme.accent, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Activity").uiFont(17, .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Every scan and every deletion, newest first")
                        .uiFont(12).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button("Clear") { state.activity.removeAll() }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
            .padding(16)
            .background(Theme.sidebar.opacity(0.5))
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }

            if state.activity.isEmpty {
                Text("Nothing logged yet.")
                    .uiFont(12)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(state.activity.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .uiFont(12, design: .monospaced)
                                .foregroundStyle(line.contains("✗") ? Risk.protected.tint : Theme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}
