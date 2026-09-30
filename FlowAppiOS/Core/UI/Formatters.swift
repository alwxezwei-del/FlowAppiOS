import Foundation

extension Int {
    func formatShort() -> String {
        let totalMinutes = self / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        if totalMinutes > 0 { return "\(minutes)m" }
        return "\(self)s"
    }

    // `12m / 45m` with an estimate, `12m` without one, `45m` if nothing focused yet
    func formatFocusProgress(estimate: Int?) -> String? {
        let focused = self > 0 ? formatShort() : nil
        let planned = estimate?.formatShort()
        if let focused, let planned { return "\(focused) / \(planned)" }
        return focused ?? planned
    }
}

extension TimeInterval {
    func formatTimer() -> String {
        let totalSeconds = Swift.max(Int(rounded(.up)), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}

extension Double {
    func formatSignedPercent() -> String {
        let percent = Int((self * 100).rounded())
        return "\(percent >= 0 ? "+" : "-")\(abs(percent))%"
    }

    func formatPercent() -> String { "\(Int((self * 100).rounded()))%" }
}

/** Time of day: 19:00 */
func formatTime(minuteOfDay: Int) -> String {
    String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
}

private let monthShortNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
private let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

func monthName(_ month: Int) -> String { monthNames[month - 1] }

extension LocalDate {
    /** Full date: Wednesday, Sep 30 */
    func formatFullDate() -> String { "\(dayOfWeek.displayName), \(monthShortNames[month - 1]) \(day)" }

    /** Short date: Mon, 12 May */
    func formatShortDate() -> String { "\(dayOfWeek.shortName), \(day) \(monthShortNames[month - 1])" }

    func dayInitial() -> String { String(dayOfWeek.displayName.prefix(1)).uppercased() }
}
