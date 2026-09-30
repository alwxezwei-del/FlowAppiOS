import Foundation

/** Current time source, injectable so tests dont depend on the real date */
protocol TimeProvider {
    func now() -> Date

    var calendar: Calendar { get }
}

extension TimeProvider {
    /** Current date in ``calendar`` */
    func today() -> LocalDate { localDate(of: now()) }

    func localDate(of instant: Date) -> LocalDate { LocalDate.from(instant, calendar: calendar) }

    func hour(of instant: Date) -> Int { calendar.component(.hour, from: instant) }
}

struct SystemTimeProvider: TimeProvider {
    func now() -> Date { Date() }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}
