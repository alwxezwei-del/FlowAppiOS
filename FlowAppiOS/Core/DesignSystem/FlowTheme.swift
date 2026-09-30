import SwiftUI

/** Semantic color tokens */
struct FlowColorScheme {
    let layer0: Color
    let layer1: Color
    let layer2: Color
    let layer3: Color
    let textMain: Color
    let textSecondary: Color
    let textTertiary: Color
    let textOnAccent: Color
    let iconMain: Color
    let iconSecondary: Color
    let primary: Color
    let success: Color
    let warning: Color
    let error: Color
    let divider: Color
    let scrim: Color
    let isDark: Bool

    func accent(_ accent: AccentColor) -> Color {
        (isDark ? Self.darkAccents : Self.lightAccents)[accent] ?? primary
    }

    func accentSurface(_ accent: AccentColor) -> Color {
        self.accent(accent).opacity(isDark ? 0.18 : 0.14)
    }

    func withPrimary(_ accent: AccentColor) -> FlowColorScheme {
        FlowColorScheme(
            layer0: layer0, layer1: layer1, layer2: layer2, layer3: layer3,
            textMain: textMain, textSecondary: textSecondary, textTertiary: textTertiary, textOnAccent: textOnAccent,
            iconMain: iconMain, iconSecondary: iconSecondary, primary: self.accent(accent),
            success: success, warning: warning, error: error, divider: divider, scrim: scrim, isDark: isDark
        )
    }

    private static let darkAccents: [AccentColor: Color] = [
        .purple: Color(hex: 0x8B7CFF),
        .violet: Color(hex: 0xA779FF),
        .blue: Color(hex: 0x5AA9FF),
        .teal: Color(hex: 0x4FD1C5),
        .green: Color(hex: 0x72D6A0),
        .orange: Color(hex: 0xF4A261),
        .pink: Color(hex: 0xEE6C9A),
    ]

    private static let lightAccents: [AccentColor: Color] = [
        .purple: Color(hex: 0x6957E8),
        .violet: Color(hex: 0x8B5CF6),
        .blue: Color(hex: 0x2D7FF9),
        .teal: Color(hex: 0x0F9E92),
        .green: Color(hex: 0x2FA46E),
        .orange: Color(hex: 0xE07C3E),
        .pink: Color(hex: 0xDB4F82),
    ]

    /** Dark palette */
    static let dark = FlowColorScheme(
        layer0: Color(hex: 0x101116),
        layer1: Color(hex: 0x181A22),
        layer2: Color(hex: 0x21232E),
        layer3: Color(hex: 0x2A2D3A),
        textMain: Color(hex: 0xF4F5F8),
        textSecondary: Color(hex: 0x9B9EAE),
        textTertiary: Color(hex: 0x6C7083),
        textOnAccent: .white,
        iconMain: Color(hex: 0xF4F5F8),
        iconSecondary: Color(hex: 0x9B9EAE),
        primary: Color(hex: 0x8B7CFF),
        success: Color(hex: 0x72D6A0),
        warning: Color(hex: 0xF4C56A),
        error: Color(hex: 0xF2698B),
        divider: Color(hex: 0x262936),
        scrim: Color(hex: 0x0B0C10, opacity: 0.8),
        isDark: true
    )

    /** Light palette */
    static let light = FlowColorScheme(
        layer0: Color(hex: 0xF7F7FA),
        layer1: .white,
        layer2: Color(hex: 0xF1F1F6),
        layer3: Color(hex: 0xE6E7EE),
        textMain: Color(hex: 0x16171D),
        textSecondary: Color(hex: 0x5E6273),
        textTertiary: Color(hex: 0x8E93A5),
        textOnAccent: .white,
        iconMain: Color(hex: 0x16171D),
        iconSecondary: Color(hex: 0x5E6273),
        primary: Color(hex: 0x6957E8),
        success: Color(hex: 0x2FA46E),
        warning: Color(hex: 0xCF9420),
        error: Color(hex: 0xD6436A),
        divider: Color(hex: 0xE4E5EC),
        scrim: Color(hex: 0x101116, opacity: 0.6),
        isDark: false
    )
}

/** Role based typography */
enum FlowTypography {
    static let display = Font.system(size: 32, weight: .medium)
    static let title1 = Font.system(size: 22, weight: .semibold)
    static let title2 = Font.system(size: 17, weight: .semibold)
    static let body1 = Font.system(size: 16)
    static let body2 = Font.system(size: 14)
    static let caption = Font.system(size: 13)
    static let button = Font.system(size: 16, weight: .semibold)
    static let timer = Font.system(size: 56, weight: .medium).monospacedDigit()
}

/** Spacing scale on a 4pt grid */
enum FlowSpacers {
    static let x2: CGFloat = 2
    static let x4: CGFloat = 4
    static let x6: CGFloat = 6
    static let x8: CGFloat = 8
    static let x12: CGFloat = 12
    static let x16: CGFloat = 16
    static let x20: CGFloat = 20
    static let x24: CGFloat = 24
    static let x32: CGFloat = 32
}

/** Corner radius scale. Cards use 18pt */
enum FlowRadius {
    static let x8: CGFloat = 8
    static let x12: CGFloat = 12
    static let x14: CGFloat = 14
    static let x18: CGFloat = 18
    static let x24: CGFloat = 24
}

let hairline: CGFloat = 1 / 3

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private struct FlowColorsKey: EnvironmentKey {
    static let defaultValue = FlowColorScheme.dark
}

extension EnvironmentValues {
    /** Design system tokens accessor */
    var flowColors: FlowColorScheme {
        get { self[FlowColorsKey.self] }
        set { self[FlowColorsKey.self] = newValue }
    }
}

/**
 * App theme
 */
struct FlowTheme: ViewModifier {
    let themeMode: ThemeMode
    let accentColor: AccentColor
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let dark = switch themeMode {
        case .system: systemScheme == .dark
        case .light: false
        case .dark: true
        }
        let colors = (dark ? FlowColorScheme.dark : FlowColorScheme.light).withPrimary(accentColor)
        content
            .environment(\.flowColors, colors)
            .tint(colors.primary)
            .onChange(of: themeMode, initial: true) { _, mode in applyWindowStyle(mode) }
    }

    /**
     * Overrides the style on the window rather than using preferredColorScheme, which doesnt
     * return to the system style reliably. Also restyles sheets, alerts and system pickers
     */
    private func applyWindowStyle(_ mode: ThemeMode) {
        let style: UIUserInterfaceStyle = switch mode {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}

extension View {
    func flowTheme(themeMode: ThemeMode, accentColor: AccentColor) -> some View {
        modifier(FlowTheme(themeMode: themeMode, accentColor: accentColor))
    }
}
