import SwiftUI
import UIKit

// MARK: - Hex Color Support

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 16, 185, 129)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Appearance Mode

enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .system: return L10n.appearanceSystem
        case .light: return L10n.appearanceLight
        case .dark: return L10n.appearanceDark
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Visual Themes (Matches Voice Notes & PosterCut Family)

enum TasaVisualTheme: String, CaseIterable, Identifiable, Sendable {
    case original
    case emerald
    case blue
    case rose
    case purple
    case amber
    case orange
    case cherry

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .original: return L10n.themeOriginalTitle
        case .emerald: return L10n.themeEmeraldTitle
        case .blue: return L10n.themeBlueTitle
        case .rose: return L10n.themeRoseTitle
        case .purple: return L10n.themePurpleTitle
        case .amber: return L10n.themeAmberTitle
        case .orange: return L10n.themeOrangeTitle
        case .cherry: return L10n.themeCherryTitle
        }
    }

    var localizedSubtitle: String {
        switch self {
        case .original: return L10n.themeOriginalSubtitle
        case .emerald: return L10n.themeEmeraldSubtitle
        case .blue: return L10n.themeBlueSubtitle
        case .rose: return L10n.themeRoseSubtitle
        case .purple: return L10n.themePurpleSubtitle
        case .amber: return L10n.themeAmberSubtitle
        case .orange: return L10n.themeOrangeSubtitle
        case .cherry: return L10n.themeCherrySubtitle
        }
    }

    var primaryAccentHex: String {
        switch self {
        case .original, .emerald: return "#10B981"
        case .blue: return "#3B82F6"
        case .rose: return "#E03E87"
        case .purple: return "#8B5CF6"
        case .amber: return "#D97706"
        case .orange: return "#EA6510"
        case .cherry: return "#DC1E47"
        }
    }

    var secondaryGlowHex: String {
        switch self {
        case .original: return "#06B6D4"
        case .emerald: return "#34D399"
        case .blue: return "#38BDF8"
        case .rose: return "#F472B6"
        case .purple: return "#A855F7"
        case .amber: return "#FBBF24"
        case .orange: return "#FB923C"
        case .cherry: return "#FB7185"
        }
    }

    var primaryAccent: Color { Color(hex: primaryAccentHex) }
    var secondaryGlow: Color { Color(hex: secondaryGlowHex) }

    var swatchColors: [Color] {
        switch self {
        case .original:
            return [Color(hex: "#10B981"), Color(hex: "#3B82F6"), Color(hex: "#06B6D4"), Color(hex: "#F59E0B")]
        case .emerald:
            return [Color(hex: "#10B981"), Color(hex: "#34D399"), Color(hex: "#0D9488"), Color(hex: "#059669")]
        case .blue:
            return [Color(hex: "#3B82F6"), Color(hex: "#06B6D4"), Color(hex: "#6366F1"), Color(hex: "#38BDF8")]
        case .rose:
            return [Color(hex: "#E03E87"), Color(hex: "#FB7185"), Color(hex: "#F472B6"), Color(hex: "#DB2777")]
        case .purple:
            return [Color(hex: "#8B5CF6"), Color(hex: "#D946EF"), Color(hex: "#6366F1"), Color(hex: "#A855F7")]
        case .amber:
            return [Color(hex: "#F59E0B"), Color(hex: "#FBBF24"), Color(hex: "#D97706"), Color(hex: "#EAB308")]
        case .orange:
            return [Color(hex: "#F97316"), Color(hex: "#FB923C"), Color(hex: "#EA580C"), Color(hex: "#F59E0B")]
        case .cherry:
            return [Color(hex: "#E11D48"), Color(hex: "#FB7185"), Color(hex: "#BE123C"), Color(hex: "#F43F5E")]
        }
    }
}

// MARK: - Theme Manager

@MainActor
final class TasaThemeManager: ObservableObject {
    static let shared = TasaThemeManager()

    private static let themeKey = "com.tasahoy.appearance.theme"
    private static let modeKey = "com.tasahoy.appearance.mode"

    @Published var currentTheme: TasaVisualTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.themeKey)
        }
    }

    @Published var appearance: AppAppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.modeKey)
        }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: Self.themeKey)
        self.currentTheme = savedTheme.flatMap(TasaVisualTheme.init(rawValue:)) ?? .original
        let savedMode = UserDefaults.standard.string(forKey: Self.modeKey)
        self.appearance = savedMode.flatMap(AppAppearanceMode.init(rawValue:)) ?? .system
    }

    var primaryAccent: Color { currentTheme.primaryAccent }
    var secondaryGlow: Color { currentTheme.secondaryGlow }

    /// Resolves the semantic accent color for any rate source:
    /// In `.original`, each currency keeps its signature recognizable color (BCV Emerald, Euro Blue, USDT Teal, Promedio Amber, COP Violet).
    /// In monochrome/tinted themes, harmonizes cleanly inside the chosen theme palette!
    func accent(for source: RateSourceID, customColorHex: String? = nil) -> Color {
        if currentTheme == .original {
            switch source {
            case .bcvUSD: return Color(hex: "#10B981")
            case .bcvEUR: return Color(hex: "#3B82F6")
            case .usdt: return Color(hex: "#06B6D4")
            case .averageBCVUSDT: return Color(hex: "#F59E0B")
            case .cop: return Color(hex: "#8B5CF6")
            case .world(let code):
                return Color(hex: WorldCurrencyPreset.preset(for: code)?.colorHex ?? "#0EA5E9")
            case .custom:
                return Color(hex: customColorHex ?? "#EC4899")
            }
        } else {
            let swatches = currentTheme.swatchColors
            switch source {
            case .bcvUSD: return swatches[0]
            case .bcvEUR: return swatches[1]
            case .usdt: return swatches[2]
            case .averageBCVUSDT: return swatches[3]
            case .cop: return swatches[1]
            case .world: return swatches[2]
            case .custom: return swatches[0]
            }
        }
    }
}

// MARK: - Native iOS 26+ Liquid Glass Modifiers (with graceful iOS 17–25 fallback)

extension View {
    @ViewBuilder
    func liquidGlassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .circle)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .circle)
                } else {
                    self.glassEffect(.regular, in: .circle)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        if let tint {
                            Circle().fill(tint.opacity(0.24))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.42), Color.white.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.85
                        )
                )
        }
    }

    @ViewBuilder
    func liquidGlassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular.tint(tint), in: .capsule)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    self.glassEffect(.regular, in: .capsule)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        if let tint {
                            Capsule().fill(tint.opacity(0.24))
                        }
                    }
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.85)
                )
        }
    }

    @ViewBuilder
    func liquidGlassRoundedRect(cornerRadius: CGFloat = 24, tint: Color? = nil, interactive: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            if let tint {
                if interactive {
                    self.glassEffect(.regular.tint(tint).interactive(), in: shape)
                } else {
                    self.glassEffect(.regular.tint(tint), in: shape)
                }
            } else {
                if interactive {
                    self.glassEffect(.regular.interactive(), in: shape)
                } else {
                    self.glassEffect(.regular, in: shape)
                }
            }
        } else {
            self
                .background(
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint {
                            shape.fill(tint.opacity(0.22))
                        }
                    }
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                )
        }
    }

    /// Lightweight GPU-cool native card surface for scrolling content (keeps the iPhone cool & 120fps!).
    func tasaCardSurface(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        self.modifier(TasaCardSurfaceModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

private struct TasaCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(
                ZStack {
                    shape.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.90 : 0.96))
                    if let tint {
                        shape.fill(
                            LinearGradient(
                                colors: [tint.opacity(colorScheme == .dark ? 0.14 : 0.08), tint.opacity(0.01)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                }
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            (tint ?? Color.primary).opacity(colorScheme == .dark ? 0.22 : 0.12),
                            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.045),
                radius: colorScheme == .dark ? 12 : 10,
                x: 0,
                y: 4
            )
    }
}

// MARK: - GPU-Cool Ambient Liquid Backdrop (Zero heavy full-screen Gaussian blurs!)

struct AmbientLiquidBackdrop: View {
    var activeAccent: Color? = nil
    @ObservedObject private var themeManager = TasaThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let primary = activeAccent ?? themeManager.primaryAccent
        let secondary = themeManager.secondaryGlow
        let topOpacity = colorScheme == .dark ? 0.18 : 0.11
        let botOpacity = colorScheme == .dark ? 0.12 : 0.07

        ZStack {
            Color(uiColor: .systemGroupedBackground)

            RadialGradient(
                colors: [primary.opacity(topOpacity), .clear],
                center: UnitPoint(x: 0.18, y: 0.08),
                startRadius: 12,
                endRadius: 360
            )

            RadialGradient(
                colors: [secondary.opacity(botOpacity), .clear],
                center: UnitPoint(x: 0.88, y: 0.82),
                startRadius: 12,
                endRadius: 330
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
