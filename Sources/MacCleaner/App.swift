import AppKit
import SwiftUI

struct SweepApp: App {
    @StateObject private var state = AppState()
    @State private var menuBarVisible = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(state)
                .onAppear {
                    state.applyAppearance()
                    menuBarVisible = state.showMenuBarItem
                    state.scanSafeCategories()
                }
                .onChange(of: state.showMenuBarItem) { _, shown in menuBarVisible = shown }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Scan") {
                Button("Scan Everything") { state.scanAll() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Quick Scan") { state.scanSafeCategories() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Select Every Safe Item") { state.selectSafeDefaults() }
                Button("Clear Selection") { state.clearSelection() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!state.hasSelection)
            }
        }

        MenuBarExtra(isInserted: $menuBarVisible) {
            MenuBarPanel().environmentObject(state)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: state.reclaimableTotal > 0 ? "scissors.circle.fill" : "scissors.circle")
                if !state.menuBarLabel.isEmpty {
                    Text(state.menuBarLabel)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarPanel: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                SweepMark(size: 26)
                VStack(alignment: .leading, spacing: -1) {
                    Text(Brand.name).uiFont(13, .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(formatBytes(state.disk.free)) free · \(Int(state.disk.usedFraction * 100))% used")
                        .uiFont(11)
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(formatBytes(state.reclaimableTotal))
                    .uiFont(28, .bold, design: .default)
                    .foregroundStyle(Theme.signature)
                Text("reclaimable across \(state.allItems.count) items")
                    .uiFont(11)
                    .foregroundStyle(Theme.textTertiary)
            }

            if !state.scannedCategories.isEmpty {
                VStack(spacing: 4) {
                    ForEach(state.scannedCategories) { category in
                        HStack(spacing: 7) {
                            Circle().fill(category.accent).frame(width: 5, height: 5)
                            Text(category.rawValue)
                                .uiFont(12)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(formatBytes(state.total(in: category)))
                                .uiFont(11, .semibold, design: .monospaced)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
            }

            Divider().overlay(Theme.stroke)

            HStack(spacing: 8) {
                Button {
                    state.scanSafeCategories()
                } label: {
                    Label("Quick Scan", systemImage: "bolt.fill")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .disabled(state.isScanning)

                Button("Open \(Brand.name)") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .uiFont(12)
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Quit \(Brand.name)")
            }

            if state.scanInterval != .off {
                Text("Auto-scan \(state.scanInterval.label.lowercased())")
                    .uiFont(11)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(14)
        .frame(width: 264)
        .background(Theme.canvas)
    }
}

/// The mark: a fanned trail of three slashes, each shorter and fainter than the last —
/// the motion a sweep leaves behind. Straight lines only, so it survives 16pt.
struct SweepMark: View {
    var size: CGFloat = 32
    var bordered = true

    /// (x1, y1, x2, y2, opacity), all as fractions of the tile.
    static let strokes: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.22, 0.76, 0.48, 0.24, 1.00),
        (0.47, 0.76, 0.67, 0.36, 0.66),
        (0.69, 0.76, 0.83, 0.48, 0.42)
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(Theme.canvas)
            .frame(width: size, height: size)
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                }
            }
            .overlay {
                Canvas { context, canvasSize in
                    let s = canvasSize.width
                    for (x1, y1, x2, y2, opacity) in Self.strokes {
                        var stroke = Path()
                        stroke.move(to: CGPoint(x: s * x1, y: s * y1))
                        stroke.addLine(to: CGPoint(x: s * x2, y: s * y2))
                        context.stroke(stroke,
                                       with: .color(Theme.markForeground.opacity(opacity)),
                                       style: StrokeStyle(lineWidth: s * 0.085, lineCap: .round))
                    }
                }
                .frame(width: size, height: size)
            }
    }
}
