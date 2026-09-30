import Foundation

extension Int {
    /// Seconds as "1h 40m", "45m" or "30s".
    var durationText: String {
        let minutes = self / 60
        switch (minutes / 60, minutes % 60) {
        case let (h, m) where h > 0 && m > 0: return "\(h)h \(m)m"
        case let (h, _) where h > 0: return "\(h)h"
        case let (_, m) where m > 0: return "\(m)m"
        default: return "\(self)s"
        }
    }
}

extension TimeInterval {
    /// "25:00", or "1:05:00" for an hour or more.
    var timerText: String {
        let total = Swift.max(Int(rounded(.up)), 0)
        let (h, m, s) = (total / 3600, total % 3600 / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

extension Double {
    var percentText: String { "\(Int((self * 100).rounded()))%" }

    var signedPercentText: String {
        let value = Int((self * 100).rounded())
        return value >= 0 ? "+\(value)%" : "\(value)%"
    }
}

func timeText(minuteOfDay: Int) -> String {
    String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
}

let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

extension LocalDate {
    /// "Wednesday, Sep 30"
    var fullText: String { "\(dayOfWeek.name), \(monthNames[month - 1].prefix(3)) \(day)" }

    /// "Wed, 30 Sep"
    var shortText: String { "\(dayOfWeek.shortName), \(day) \(monthNames[month - 1].prefix(3))" }

    var initial: String { String(dayOfWeek.name.prefix(1)) }
}

extension FlowTask {
    /// "20m / 45m" with an estimate, "20m" without one, "45m" when nothing is focused yet.
    var focusText: String? {
        let focused = focusedSeconds > 0 ? focusedSeconds.durationText : nil
        let planned = estimateSeconds?.durationText
        if let focused, let planned { return "\(focused) / \(planned)" }
        return focused ?? planned
    }
}

extension Priority {
    var title: String { rawValue.capitalized }
}

extension FocusKind {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

extension HabitSchedule {
    var title: String {
        switch self {
        case .daily: "Every day"
        case .selectedDays(let days): DayOfWeek.allCases.filter(days.contains).map(\.shortName).joined(separator: ", ")
        }
    }
}

extension Array where Element == String? {
    /// Joins the non-empty parts with " · ", `nil` if there are none.
    var dotted: String? {
        let parts = compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
