import Foundation

/// Day of week. Raw value matches the Android ordinal (Monday = 0), which is what backups store.
enum DayOfWeek: Int, CaseIterable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var name: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }

    var shortName: String { String(name.prefix(3)) }
}

/// A calendar date without time or time zone, stored as days since 1970-01-01.
/// Encodes as that number, same as `LocalDate.toEpochDays()` on Android.
struct LocalDate: Hashable, Comparable, Codable, CustomStringConvertible {
    let epochDay: Int

    init(epochDay: Int) {
        self.epochDay = epochDay
    }

    init(year: Int, month: Int, day: Int) {
        // days_from_civil, see https://howardhinnant.github.io/date_algorithms.html
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        epochDay = era * 146_097 + doe - 719_468
    }

    init(from decoder: Decoder) throws {
        epochDay = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(epochDay)
    }

    static func from(_ date: Date, calendar: Calendar) -> LocalDate {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    private var civil: (year: Int, month: Int, day: Int) {
        let z = epochDay + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    var year: Int { civil.year }
    var month: Int { civil.month }
    var day: Int { civil.day }

    // 1970-01-01 was a Thursday
    var dayOfWeek: DayOfWeek { DayOfWeek(rawValue: ((epochDay + 3) % 7 + 7) % 7)! }

    func plusDays(_ days: Int) -> LocalDate { LocalDate(epochDay: epochDay + days) }

    func minusDays(_ days: Int) -> LocalDate { plusDays(-days) }

    /// Keeps the day where possible, clamps it at the end of shorter months (Jan 31 + 1 → Feb 28).
    func plusMonths(_ months: Int) -> LocalDate {
        let total = year * 12 + (month - 1) + months
        let newYear = total / 12
        let newMonth = total % 12 + 1
        let firstOfMonth = LocalDate(year: newYear, month: newMonth, day: 1)
        let daysInMonth = firstOfMonth.plusMonthsUnclamped(1).epochDay - firstOfMonth.epochDay
        return LocalDate(year: newYear, month: newMonth, day: min(day, daysInMonth))
    }

    private func plusMonthsUnclamped(_ months: Int) -> LocalDate {
        let total = year * 12 + (month - 1) + months
        return LocalDate(year: total / 12, month: total % 12 + 1, day: day)
    }

    func startOfWeek(_ firstDay: DayOfWeek) -> LocalDate {
        minusDays((dayOfWeek.rawValue - firstDay.rawValue + 7) % 7)
    }

    func startOfDay(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool { lhs.epochDay < rhs.epochDay }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

struct DateRange: Hashable {
    let start: LocalDate
    let end: LocalDate

    func contains(_ date: LocalDate) -> Bool { start <= date && date <= end }

    var days: [LocalDate] {
        start <= end ? (start.epochDay...end.epochDay).map(LocalDate.init(epochDay:)) : []
    }

    func contains(_ instant: Date, calendar: Calendar) -> Bool {
        contains(LocalDate.from(instant, calendar: calendar))
    }
}
