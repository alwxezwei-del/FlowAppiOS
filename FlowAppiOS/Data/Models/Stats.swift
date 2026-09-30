import Foundation

enum StatsPeriod: CaseIterable, Hashable {
    case week, month, year
}

struct DailyFocus: Hashable {
    let date: LocalDate
    let seconds: Int
}

struct CategoryFocus: Hashable {
    /// `nil` groups sessions without a category.
    let categoryId: String?
    let name: String
    let color: AccentColor
    let seconds: Int
    let share: Double
}

struct HabitConsistency: Hashable {
    let habit: Habit
    let completedDays: Int
    let scheduledDays: Int

    var rate: Double { scheduledDays > 0 ? Double(completedDays) / Double(scheduledDays) : 0 }
}

struct StatsSummary: Hashable {
    let range: DateRange
    var focusSeconds = 0
    var previousFocusSeconds = 0
    /// One entry per day of the period, zero for days without focus.
    var dailyFocus: [DailyFocus] = []
    var completedTasks = 0
    var totalTasks = 0
    var categories: [CategoryFocus] = []
    var habits: [HabitConsistency] = []

    var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }

    /// Change against the previous period, `nil` when there is nothing to compare with.
    var focusTrend: Double? {
        previousFocusSeconds > 0 ? Double(focusSeconds - previousFocusSeconds) / Double(previousFocusSeconds) : nil
    }

    var hasData: Bool { focusSeconds > 0 || totalTasks > 0 || !habits.isEmpty }
}

struct HabitStreaks: Hashable {
    var current = 0
    var longest = 0
    var completedDays = 0
    var scheduledDays = 0

    var completionRate: Double { scheduledDays > 0 ? Double(completedDays) / Double(scheduledDays) : 0 }
}

enum HistoryFilter: CaseIterable, Hashable {
    case all, focus, tasks, habits
}

enum HistoryEvent: Hashable, Identifiable {
    case taskCompleted(FlowTask, category: Category?, at: Date)
    case habitCompleted(Habit, completion: HabitCompletion)
    case focusFinished(FocusSession, taskTitle: String?)

    var id: String {
        switch self {
        case .taskCompleted(let task, _, _): task.id
        case .habitCompleted(_, let completion): completion.id
        case .focusFinished(let session, _): session.id
        }
    }

    var date: Date {
        switch self {
        case .taskCompleted(_, _, let at): at
        case .habitCompleted(_, let completion): completion.completedAt
        case .focusFinished(let session, _): session.endedAt
        }
    }
}
