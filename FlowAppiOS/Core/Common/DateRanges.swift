import Foundation

/** Statistics period bounds */
func statisticsRange(period: StatisticsPeriod, today: LocalDate, startOfWeek: DayOfWeek) -> DateRange {
    switch period {
    case .week:
        let start = today.startOfWeek(startOfWeek)
        return DateRange(start: start, endInclusive: start.plusDays(6))
    case .month:
        let start = LocalDate(year: today.year, month: today.month, day: 1)
        return DateRange(start: start, endInclusive: start.plusMonths(1).minusDays(1))
    case .year:
        return DateRange(start: LocalDate(year: today.year, month: 1, day: 1), endInclusive: LocalDate(year: today.year, month: 12, day: 31))
    }
}

/** Previous period of the same length */
func previousRange(period: StatisticsPeriod, range: DateRange) -> DateRange {
    switch period {
    case .week:
        return DateRange(start: range.start.minusDays(7), endInclusive: range.endInclusive.minusDays(7))
    case .month:
        let start = range.start.plusMonths(-1)
        return DateRange(start: start, endInclusive: range.start.minusDays(1))
    case .year:
        return DateRange(start: range.start.plusYears(-1), endInclusive: range.endInclusive.plusYears(-1))
    }
}

extension LocalDate {
    /** Start of the week containing this date */
    func startOfWeek(_ startOfWeek: DayOfWeek) -> LocalDate {
        let shift = (dayOfWeek.isoDayNumber - startOfWeek.isoDayNumber + 7) % 7
        return minusDays(shift)
    }
}

extension DateRange {
    /** All days in the range, inclusive */
    var days: [LocalDate] {
        guard start <= endInclusive else { return [] }
        return (start.epochDay...endInclusive.epochDay).map(LocalDate.init(epochDay:))
    }

    /** Instant bounds of the range: start of the first day up to the end of the last one */
    func instants(in calendar: Calendar) -> ClosedRange<Date> {
        let from = start.startOfDay(in: calendar)
        let to = endInclusive.plusDays(1).startOfDay(in: calendar).addingTimeInterval(-0.001)
        return from...max(from, to)
    }
}
