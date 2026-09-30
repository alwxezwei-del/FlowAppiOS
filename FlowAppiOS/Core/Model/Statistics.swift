import Foundation

/**
 * Statistics period
 *
 * `rawValue` - stable storage key
 */
enum StatisticsPeriod: String, CaseIterable, Hashable {
    case week, month, year

    static let `default`: StatisticsPeriod = .week
}

/** Inclusive date range */
struct DateRange: Hashable {
    let start: LocalDate
    let endInclusive: LocalDate

    func contains(_ date: LocalDate) -> Bool { date >= start && date <= endInclusive }
}

/** Focused time for one day */
struct DailyFocus: Hashable {
    let date: LocalDate
    let seconds: Int
}

/**
 * Focused time per category
 */
struct CategoryFocus: Hashable {
    /** nil = uncategorized */
    let categoryId: String?
    let categoryName: String
    let color: AccentColor
    let seconds: Int
    /** 0-1f */
    let share: Double
}

/**
 * Habit consistency over a period
 */
struct HabitConsistency: Hashable {
    let habitId: String
    let habitName: String
    let icon: String
    let color: AccentColor
    /** scheduled days with the target reached */
    let completedDays: Int
    let scheduledDays: Int

    var rate: Double { scheduledDays <= 0 ? 0 : Double(completedDays) / Double(scheduledDays) }
}

/**
 * Statistics screen summary, computed on the fly from the database
 */
struct StatisticsSummary: Hashable {
    let period: StatisticsPeriod
    let range: DateRange
    var totalFocusSeconds: Int = 0
    /** same value for the previous period, for comparison */
    var previousTotalFocusSeconds: Int = 0
    var dailyFocus: [DailyFocus] = []
    var completedTasks: Int = 0
    var totalTasks: Int = 0
    var categories: [CategoryFocus] = []
    var habits: [HabitConsistency] = []

    var completionRate: Double { totalTasks <= 0 ? 0 : Double(completedTasks) / Double(totalTasks) }

    var focusTrend: Double? {
        guard previousTotalFocusSeconds > 0 else { return nil }
        return Double(totalFocusSeconds - previousTotalFocusSeconds) / Double(previousTotalFocusSeconds)
    }
}

/**
 * History event type, used as a filter
 *
 * `rawValue` - stable storage key
 */
enum HistoryFilter: String, CaseIterable, Hashable {
    case all, focus, tasks, habits

    static let `default`: HistoryFilter = .all
}

/** History feed event, built from tasks, habit completions and focus sessions */
enum HistoryEvent: Hashable {
    /**
     * Task completed
     *
     * - Parameter categoryName: nil = no category
     */
    case taskCompleted(id: String, timestamp: Date, title: String, categoryName: String?, color: AccentColor)
    /** Habit completed */
    case habitCompleted(id: String, timestamp: Date, habitName: String, icon: String, color: AccentColor)
    /**
     * Focus session finished
     *
     * - Parameter taskTitle: nil for a free session
     * - Parameter completed: timer reached zero
     */
    case focusFinished(id: String, timestamp: Date, taskTitle: String?, kind: FocusKind, seconds: Int, completed: Bool)

    /** List key */
    var id: String {
        switch self {
        case .taskCompleted(let id, _, _, _, _), .habitCompleted(let id, _, _, _, _), .focusFinished(let id, _, _, _, _, _): id
        }
    }

    /** Sort key for the feed */
    var timestamp: Date {
        switch self {
        case .taskCompleted(_, let timestamp, _, _, _), .habitCompleted(_, let timestamp, _, _, _), .focusFinished(_, let timestamp, _, _, _, _): timestamp
        }
    }
}
