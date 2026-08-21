import SwiftUI

private struct Channels {
    let red: Double
    let green: Double
    let blue: Double
    var alpha: Double = 1

    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}

/// Dynamic colours resolved by the system appearance, so one token set drives light and dark.
private func dynamic(light: Channels, dark: Channels) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return (isDark ? dark : light).nsColor
    })
}

private func hex(_ value: UInt32) -> Channels {
    Channels(red: Double((value >> 16) & 0xFF) / 255,
             green: Double((value >> 8) & 0xFF) / 255,
             blue: Double(value & 0xFF) / 255)
}

private func solid(_ value: UInt32) -> Color {
    Color(nsColor: hex(value).nsColor)
}

/// Palette follows Vercel's system: true black canvas, near-black surfaces, hairline borders,
/// #EDEDED text rather than pure white, and colour only where it carries meaning.
enum Theme {
    static let canvas = dynamic(light: hex(0xFFFFFF), dark: hex(0x000000))
    static let surface = dynamic(light: hex(0xFAFAFA), dark: hex(0x0A0A0A))
    static let surfaceRaised = dynamic(light: hex(0xF2F2F2), dark: hex(0x171717))
    static let sidebar = dynamic(light: hex(0xFAFAFA), dark: hex(0x000000))
    static let stroke = dynamic(light: hex(0xEAEAEA), dark: hex(0x1F1F1F))
    static let strokeStrong = dynamic(light: hex(0xD4D4D4), dark: hex(0x2E2E2E))

    static let textPrimary = dynamic(light: hex(0x0A0A0A), dark: hex(0xEDEDED))
    static let textSecondary = dynamic(light: hex(0x666666), dark: hex(0xA1A1A1))
    static let textTertiary = dynamic(light: hex(0x8F8F8F), dark: hex(0x737373))

    static let accent = solid(0x3291FF)
    static let accentDeep = solid(0x0070F3)

    static let pink = solid(0xFF0080)
    static let purple = solid(0x8A63D2)
    static let cyan = solid(0x50E3C2)
    static let amber = solid(0xF5A623)
    static let green = solid(0x0CCE6B)
    static let yellow = solid(0xFFD666)

    /// Reserved for irreversible actions and failures — never for classification.
    static let danger = solid(0xFF4D4D)

    /// The mark inverts against the canvas: white glyph on black, black on white.
    static let markForeground = dynamic(light: hex(0x0A0A0A), dark: hex(0xEDEDED))

    /// The one flourish: the mark and the headline figure. Nothing else.
    static let signature = LinearGradient(colors: [pink, purple],
                                          startPoint: .leading, endPoint: .trailing)
}

extension Category {
    var accent: Color {
        switch self {
        case .devCaches: return Theme.accent
        case .appJunk: return Theme.pink
        case .projects: return Theme.purple
        case .tools: return Theme.cyan
        case .gitRepos: return Theme.amber
        case .largeFiles: return Theme.green
        case .duplicates: return Theme.yellow
        }
    }
}

extension Risk {
    var tint: Color {
        switch self {
        case .safe: return Theme.green
        case .rebuild: return Theme.amber
        // Deliberately not red. Red is reserved for destructive intent and failures.
        case .protected: return Theme.purple
        }
    }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 8) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

// MARK: - Controls

/// Vercel's primary action: solid foreground on the canvas colour. No glow, no gradient.
struct PrimaryButtonStyle: ButtonStyle {
    var compact = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(destructive ? Color.white : Theme.canvas)
            .padding(.horizontal, compact ? 11 : 15)
            .padding(.vertical, compact ? 5 : 8)
            .background(destructive ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Theme.textPrimary),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, compact ? 11 : 15)
            .padding(.vertical, compact ? 5 : 8)
            .background(configuration.isPressed ? Theme.surfaceRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.strokeStrong, lineWidth: 1)
            }
    }
}

struct CheckToggleStyle: ToggleStyle {
    var tint: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(configuration.isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Color.clear))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(configuration.isOn ? tint : Theme.strokeStrong, lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "checkmark")
                        .uiFont(11, .black)
                        .foregroundStyle(Theme.canvas)
                        .opacity(configuration.isOn ? 1 : 0)
                }
                .frame(width: 16, height: 16)
                .animation(.easeOut(duration: 0.12), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small pieces

struct GlyphChip: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
    }
}

struct RiskBadge: View {
    let risk: Risk

    var body: some View {
        Text(risk.label)
            .uiFont(11, .medium, design: .monospaced)
            .tracking(0.3)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(risk.tint.opacity(0.4), lineWidth: 1)
            }
            .foregroundStyle(risk.tint)
            .help(risk.explanation)
    }
}

// MARK: - Type scale

/// macOS honours System Settings › Accessibility › Display › Text size through the
/// dynamicTypeSize environment, which plain `.system(size:)` ignores. @ScaledMetric opts
/// every label back into that scaling.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func uiFont(_ size: CGFloat,
                _ weight: Font.Weight = .regular,
                design: Font.Design = .default,
                relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, relativeTo: style))
    }
}

// MARK: - Motion

enum Motion {
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.82)
    static let quick = Animation.easeOut(duration: 0.16)
    static let panel = Animation.spring(response: 0.38, dampingFraction: 0.86)
}

/// A highlight that travels across a surface. Two gradient layers, GPU-composited —
/// it costs nothing measurable and only runs while `active`.
struct Shimmer: ViewModifier {
    var active: Bool
    var radius: CGFloat = 6

    @State private var phase: CGFloat = -0.6

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Theme.canvas.opacity(0.45), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.55)
                        .offset(x: phase * geo.size.width * 1.9)
                }
                .mask(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
                .onAppear {
                    withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                        phase = 0.75
                    }
                }
            }
        }
    }
}

extension View {
    func shimmer(active: Bool, radius: CGFloat = 6) -> some View {
        modifier(Shimmer(active: active, radius: radius))
    }
}

// MARK: - Segmented tabs

struct SegmentedTabs<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let label: String
        var icon: String?
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let active = option.value == selection

                Button {
                    withAnimation(Motion.snap) { selection = option.value }
                } label: {
                    HStack(spacing: 5) {
                        if let icon = option.icon {
                            Image(systemName: icon).uiFont(10, .medium)
                        }
                        Text(option.label).uiFont(11, active ? .semibold : .medium)
                    }
                    .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Theme.surfaceRaised)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(Theme.strokeStrong, lineWidth: 1)
                                }
                                .matchedGeometryEffect(id: "segment", in: namespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
