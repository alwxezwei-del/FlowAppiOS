import Foundation

/** ISO day of week, Monday first. `ordinal` matches kotlinx.datetime.DayOfWeek.ordinal */
enum DayOfWeek: Int, CaseIterable, Codable, Hashable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var ordinal: Int { rawValue }

    /** ISO day number, Monday = 1 */
    var isoDayNumber: Int { rawValue + 1 }

    var displayName: String {
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

    var shortName: String { String(displayName.prefix(3)) }
}

/**
 * Calendar date without time zone, stored as days since 1970-01-01.
 * Mirrors kotlinx.datetime.LocalDate so backups are interchangeable with Android
 */
struct LocalDate: Hashable, Comparable, Codable, CustomStringConvertible {
    let epochDay: Int

    init(epochDay: Int) {
        self.epochDay = epochDay
    }

    init(year: Int, month: Int, day: Int) {
        // Howard Hinnant's days_from_civil
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
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

    /** 1970-01-01 was a Thursday */
    var dayOfWeek: DayOfWeek {
        DayOfWeek(rawValue: ((epochDay + 3) % 7 + 7) % 7)!
    }

    func plusDays(_ days: Int) -> LocalDate { LocalDate(epochDay: epochDay + days) }

    func minusDays(_ days: Int) -> LocalDate { plusDays(-days) }

    func plusMonths(_ months: Int) -> LocalDate {
        let (year, month, day) = civil
        let total = year * 12 + (month - 1) + months
        let newYear = Int((Double(total) / 12).rounded(.down))
        let newMonth = total - newYear * 12 + 1
        return LocalDate(year: newYear, month: newMonth, day: min(day, LocalDate.daysIn(month: newMonth, year: newYear)))
    }

    func plusYears(_ years: Int) -> LocalDate { plusMonths(years * 12) }

    static func daysIn(month: Int, year: Int) -> Int {
        let next = month == 12 ? LocalDate(year: year + 1, month: 1, day: 1) : LocalDate(year: year, month: month + 1, day: 1)
        return next.epochDay - LocalDate(year: year, month: month, day: 1).epochDay
    }

    /** Start of the day in the given calendar's time zone */
    func startOfDay(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
    }

    static func from(_ date: Date, calendar: Calendar) -> LocalDate {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(year: components.year ?? 1970, month: components.month ?? 1, day: components.day ?? 1)
    }

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool { lhs.epochDay < rhs.epochDay }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}
