import Foundation
import Observation

/** App settings in UserDefaults */
@MainActor
@Observable
final class SettingsStore {
    /** Falls back to defaults on read errors */
    private(set) var settings: AppSettings

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = SettingsStore.read(from: defaults)
    }

    func update(_ settings: AppSettings) {
        self.settings = settings
        defaults.set(settings.themeMode.rawValue, forKey: Keys.themeMode)
        defaults.set(settings.accentColor.rawValue, forKey: Keys.accentColor)
        defaults.set(settings.focusMinutes, forKey: Keys.focusMinutes)
        defaults.set(settings.shortBreakMinutes, forKey: Keys.shortBreakMinutes)
        defaults.set(settings.longBreakMinutes, forKey: Keys.longBreakMinutes)
        defaults.set(settings.startOfWeek.ordinal, forKey: Keys.startOfWeek)
        defaults.set(settings.notificationsEnabled, forKey: Keys.notifications)
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        var copy = settings
        transform(&copy)
        update(copy)
    }

    /** Resets settings to defaults */
    func clear() {
        Keys.all.forEach(defaults.removeObject(forKey:))
        settings = AppSettings()
    }

    private static func read(from defaults: UserDefaults) -> AppSettings {
        AppSettings(
            themeMode: .parse(defaults.string(forKey: Keys.themeMode)),
            accentColor: .parse(defaults.string(forKey: Keys.accentColor)),
            focusMinutes: defaults.object(forKey: Keys.focusMinutes) as? Int ?? AppSettings.defaultFocusMinutes,
            shortBreakMinutes: defaults.object(forKey: Keys.shortBreakMinutes) as? Int ?? AppSettings.defaultShortBreakMinutes,
            longBreakMinutes: defaults.object(forKey: Keys.longBreakMinutes) as? Int ?? AppSettings.defaultLongBreakMinutes,
            startOfWeek: DayOfWeek(rawValue: defaults.integer(forKey: Keys.startOfWeek)) ?? .monday,
            notificationsEnabled: defaults.object(forKey: Keys.notifications) as? Bool ?? true
        )
    }

    private enum Keys {
        static let themeMode = "theme_mode"
        static let accentColor = "accent_color"
        static let focusMinutes = "focus_minutes"
        static let shortBreakMinutes = "short_break_minutes"
        static let longBreakMinutes = "long_break_minutes"
        static let startOfWeek = "start_of_week"
        static let notifications = "notifications_enabled"

        static let all = [themeMode, accentColor, focusMinutes, shortBreakMinutes, longBreakMinutes, startOfWeek, notifications]
    }
}
