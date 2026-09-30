import SwiftUI

struct FlowPalette {
    let layer0: Color
    let layer1: Color
    let layer2: Color
    let layer3: Color
    let textMain: Color
    let textSecondary: Color
    let textTertiary: Color
    let primary: Color
    let success: Color
    let warning: Color
    let error: Color
    let divider: Color
    let isDark: Bool

    static func palette(for scheme: ColorScheme, accent: AccentColor) -> FlowPalette {
        let primary = accent.color(for: scheme)
        if scheme == .dark {
            return FlowPalette(layer0: Color(hex: 0x101116), layer1: Color(hex: 0x181A22), layer2: Color(hex: 0x21232E), layer3: Color(hex: 0x2A2D3A), textMain: Color(hex: 0xF4F5F8), textSecondary: Color(hex: 0x9B9EAE), textTertiary: Color(hex: 0x6C7083), primary: primary, success: Color(hex: 0x72D6A0), warning: Color(hex: 0xF4C56A), error: Color(hex: 0xF2698B), divider: Color(hex: 0x262936), isDark: true)
        }
        return FlowPalette(layer0: Color(hex: 0xF7F7FA), layer1: .white, layer2: Color(hex: 0xF1F1F6), layer3: Color(hex: 0xE6E7EE), textMain: Color(hex: 0x16171D), textSecondary: Color(hex: 0x5E6273), textTertiary: Color(hex: 0x8E93A5), primary: primary, success: Color(hex: 0x2FA46E), warning: Color(hex: 0xCF9420), error: Color(hex: 0xD6436A), divider: Color(hex: 0xE4E5EC), isDark: false)
    }
}

extension AccentColor {
    func color(for scheme: ColorScheme) -> Color {
        switch (self, scheme == .dark) {
        case (.purple, true): Color(hex: 0x8B7CFF)
        case (.violet, true): Color(hex: 0xA779FF)
        case (.blue, true): Color(hex: 0x5AA9FF)
        case (.teal, true): Color(hex: 0x4FD1C5)
        case (.green, true): Color(hex: 0x72D6A0)
        case (.orange, true): Color(hex: 0xF4A261)
        case (.pink, true): Color(hex: 0xEE6C9A)
        case (.purple, false): Color(hex: 0x6957E8)
        case (.violet, false): Color(hex: 0x8B5CF6)
        case (.blue, false): Color(hex: 0x2D7FF9)
        case (.teal, false): Color(hex: 0x0F9E92)
        case (.green, false): Color(hex: 0x2FA46E)
        case (.orange, false): Color(hex: 0xE07C3E)
        case (.pink, false): Color(hex: 0xDB4F82)
        }
    }
}

extension Color {
    init(hex: UInt) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

private struct FlowPaletteKey: EnvironmentKey {
    static let defaultValue = FlowPalette.palette(for: .light, accent: .purple)
}

extension EnvironmentValues {
    var flow: FlowPalette {
        get { self[FlowPaletteKey.self] }
        set { self[FlowPaletteKey.self] = newValue }
    }
}

struct FlowThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var store: FlowStore

    func body(content: Content) -> some View {
        content
            .environment(\.flow, FlowPalette.palette(for: effectiveScheme, accent: store.settings.accentColor))
            .preferredColorScheme(preferredScheme)
            .tint(FlowPalette.palette(for: effectiveScheme, accent: store.settings.accentColor).primary)
    }

    private var preferredScheme: ColorScheme? {
        switch store.settings.themeMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var effectiveScheme: ColorScheme {
        preferredScheme ?? scheme
    }
}

extension View {
    func flowThemed() -> some View { modifier(FlowThemeModifier()) }
}
