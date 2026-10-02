import Foundation

// Everything user-facing goes through Foundation format styles, so day and month names,
// 12/24-hour time and number formats follow the device settings.

extension Int {
    /// Seconds as "1h 40m", "45m" or "30s".
    var durationText: String {
        let units: Set<Duration.UnitsFormatStyle.Unit> = self < 60 ? [.seconds] : [.hours, .minutes]
        return Duration.seconds(self).formatted(.units(allowed: units, width: .narrow))
    }
}

extension TimeInterval {
    /// "25:00", or "1:05:00" for an hour or more.
    var timerText: String {
        let duration = Duration.seconds(Swift.max(rounded(.up), 0))
        return duration.formatted(.time(pattern: self >= 3600 ? .hourMinuteSecond : .minuteSecond(padMinuteToLength: 2)))
    }
}

extension Double {
    var percentText: String {
        formatted(.percent.precision(.fractionLength(0)))
    }

    var signedPercentText: String {
        formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
    }
}

/// Time of day for minutes since midnight, e.g. "19:00" or "7:00 PM".
func timeText(minuteOfDay: Int) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60)) ?? .now
    return date.formatted(date: .omitted, time: .shortened)
}

extension LocalDate {
    private var date: Date { startOfDay(in: .current) }

    /// "Wednesday, Sep 30"
    var fullText: String { date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }

    /// "Wed, Sep 30"
    var shortText: String { date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) }

    /// "W"
    var initial: String { date.formatted(.dateTime.weekday(.narrow)) }

    /// "September"
    var monthText: String { date.formatted(.dateTime.month(.wide)) }

    /// "S"
    var monthInitial: String { date.formatted(.dateTime.month(.narrow)) }
}

extension DayOfWeek {
    // Calendar symbols start on Sunday, our days start on Monday
    private var symbolIndex: Int { (rawValue + 1) % 7 }

    var name: String { Calendar.current.weekdaySymbols[symbolIndex] }

    var shortName: String { Calendar.current.shortWeekdaySymbols[symbolIndex] }
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
        case .selectedDays(let days): DayOfWeek.allCases.filter(days.contains).map(\.shortName).formatted(.list(type: .and, width: .narrow))
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
