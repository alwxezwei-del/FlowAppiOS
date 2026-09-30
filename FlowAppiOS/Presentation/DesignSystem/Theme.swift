import SwiftUI
import UIKit

/// Color tokens, same values as the Android theme.
struct Palette {
    let layer0: Color
    let layer1: Color
    let layer2: Color
    let layer3: Color
    let textMain: Color
    let textSecondary: Color
    let textTertiary: Color
    let iconMain: Color
    let iconSecondary: Color
    let success: Color
    let error: Color
    let divider: Color
    let isDark: Bool
    var primary: Color

    let textOnAccent = Color.white

    func accent(_ accent: AccentColor) -> Color {
        Color(hex: (isDark ? Self.darkAccents : Self.lightAccents)[accent]!)
    }

    func accentSurface(_ accent: AccentColor) -> Color {
        self.accent(accent).opacity(isDark ? 0.18 : 0.14)
    }

    static let dark = Palette(
        layer0: Color(hex: 0x101116), layer1: Color(hex: 0x181A22), layer2: Color(hex: 0x21232E), layer3: Color(hex: 0x2A2D3A),
        textMain: Color(hex: 0xF4F5F8), textSecondary: Color(hex: 0x9B9EAE), textTertiary: Color(hex: 0x6C7083),
        iconMain: Color(hex: 0xF4F5F8), iconSecondary: Color(hex: 0x9B9EAE),
        success: Color(hex: 0x72D6A0), error: Color(hex: 0xF2698B), divider: Color(hex: 0x262936),
        isDark: true, primary: Color(hex: 0x8B7CFF)
    )

    static let light = Palette(
        layer0: Color(hex: 0xF7F7FA), layer1: .white, layer2: Color(hex: 0xF1F1F6), layer3: Color(hex: 0xE6E7EE),
        textMain: Color(hex: 0x16171D), textSecondary: Color(hex: 0x5E6273), textTertiary: Color(hex: 0x8E93A5),
        iconMain: Color(hex: 0x16171D), iconSecondary: Color(hex: 0x5E6273),
        success: Color(hex: 0x2FA46E), error: Color(hex: 0xD6436A), divider: Color(hex: 0xE4E5EC),
        isDark: false, primary: Color(hex: 0x6957E8)
    )

    private static let darkAccents: [AccentColor: UInt] = [
        .purple: 0x8B7CFF, .violet: 0xA779FF, .blue: 0x5AA9FF, .teal: 0x4FD1C5, .green: 0x72D6A0, .orange: 0xF4A261, .pink: 0xEE6C9A,
    ]

    private static let lightAccents: [AccentColor: UInt] = [
        .purple: 0x6957E8, .violet: 0x8B5CF6, .blue: 0x2D7FF9, .teal: 0x0F9E92, .green: 0x2FA46E, .orange: 0xE07C3E, .pink: 0xDB4F82,
    ]
}

extension Color {
    init(hex: UInt) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    static let flowDisplay = Font.system(size: 32, weight: .medium)
    static let flowTitle1 = Font.system(size: 22, weight: .semibold)
    static let flowTitle2 = Font.system(size: 17, weight: .semibold)
    static let flowBody1 = Font.system(size: 16)
    static let flowBody2 = Font.system(size: 14)
    static let flowCaption = Font.system(size: 13)
    static let flowButton = Font.system(size: 16, weight: .semibold)
    static let flowTimer = Font.system(size: 56, weight: .medium).monospacedDigit()
}

extension EnvironmentValues {
    @Entry var colors = Palette.dark
}

private struct ThemeModifier: ViewModifier {
    let mode: ThemeMode
    let accent: AccentColor
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let isDark = mode == .dark || (mode == .system && systemScheme == .dark)
        var colors = isDark ? Palette.dark : Palette.light
        colors.primary = colors.accent(accent)

        return content
            .environment(\.colors, colors)
            .tint(colors.primary)
            .onChange(of: mode, initial: true) { _, mode in apply(mode) }
    }

    // preferredColorScheme(nil) doesn't reliably switch back to the system style,
    // so the style is set on the window instead. This also covers sheets and alerts.
    private func apply(_ mode: ThemeMode) {
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
    func flowTheme(_ mode: ThemeMode, accent: AccentColor) -> some View {
        modifier(ThemeModifier(mode: mode, accent: accent))
    }
}

/// SF Symbol for an icon key.
func symbol(for iconKey: String) -> String {
    switch iconKey {
    case "workout": "dumbbell"
    case "read": "book"
    case "code": "laptopcomputer"
    case "meditate": "figure.mind.and.body"
    case "heart": "heart"
    case "star": "star"
    case "water": "waterbottle"
    case "walk": "figure.walk"
    case "work": "briefcase"
    case "learning": "graduationcap"
    case "personal": "person"
    case "health": "rosette"
    default: "bolt"
    }
}
