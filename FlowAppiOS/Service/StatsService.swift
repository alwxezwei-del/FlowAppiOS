import Foundation
import Observation

/// Statistics and the activity feed, computed on the fly from the other services.
@MainActor
@Observable
final class StatsService {
    @ObservationIgnored private let tasks: TaskService
    @ObservationIgnored private let habits: HabitService
    @ObservationIgnored private let focus: FocusService
    @ObservationIgnored private let settings: SettingsService
    @ObservationIgnored private let time: TimeSource

    init(tasks: TaskService, habits: HabitService, focus: FocusService, settings: SettingsService, time: TimeSource) {
        self.tasks = tasks
        self.habits = habits
        self.focus = focus
        self.settings = settings
        self.time = time
    }

    func range(of period: StatsPeriod) -> DateRange {
        let today = time.today
        switch period {
        case .week:
            let start = today.startOfWeek(settings.settings.startOfWeek)
            return DateRange(start: start, end: start.plusDays(6))
        case .month:
            let start = LocalDate(year: today.year, month: today.month, day: 1)
            return DateRange(start: start, end: start.plusMonths(1).minusDays(1))
        case .year:
            return DateRange(start: LocalDate(year: today.year, month: 1, day: 1), end: LocalDate(year: today.year, month: 12, day: 31))
        }
    }

    func summary(for period: StatsPeriod) -> StatsSummary {
        let range = range(of: period)
        let sessions = focus.sessions(in: range).filter { $0.kind == .focus }
        let total = sessions.reduce(0) { $0 + $1.actualSeconds }
        let periodTasks = tasks.tasks(dueIn: range)

        return StatsSummary(
            range: range,
            focusSeconds: total,
            previousFocusSeconds: focus.focusSeconds(in: previousRange(range, period: period)),
            dailyFocus: dailyFocus(sessions, in: range),
            completedTasks: periodTasks.filter(\.isCompleted).count,
            totalTasks: periodTasks.filter { $0.status != .archived }.count,
            categories: categoryFocus(sessions, total: total),
            habits: habitConsistency(in: range)
        )
    }

    /// Completed tasks, habit check-ins and focus sessions of the last three months, newest first.
    func history(filter: HistoryFilter) -> [HistoryEvent] {
        let today = time.today
        let range = DateRange(start: today.plusMonths(-3), end: today)
        var events: [HistoryEvent] = []

        if filter == .all || filter == .tasks {
            for task in tasks.tasks(dueIn: range) where task.isCompleted {
                events.append(.taskCompleted(task, category: tasks.category(id: task.categoryId), at: task.completedAt ?? task.createdAt))
            }
        }
        if filter == .all || filter == .habits {
            for completion in habits.completions where range.contains(completion.date) {
                if let habit = habits.habit(id: completion.habitId) {
                    events.append(.habitCompleted(habit, completion: completion))
                }
            }
        }
        if filter == .all || filter == .focus {
            for session in focus.sessions(in: range) {
                events.append(.focusFinished(session, taskTitle: tasks.task(id: session.taskId)?.title))
            }
        }
        return events.sorted { $0.date > $1.date }
    }

    private func previousRange(_ range: DateRange, period: StatsPeriod) -> DateRange {
        switch period {
        case .week: DateRange(start: range.start.minusDays(7), end: range.end.minusDays(7))
        case .month: DateRange(start: range.start.plusMonths(-1), end: range.start.minusDays(1))
        case .year: DateRange(start: range.start.plusMonths(-12), end: range.end.plusMonths(-12))
        }
    }

    private func dailyFocus(_ sessions: [FocusSession], in range: DateRange) -> [DailyFocus] {
        let byDay = Dictionary(grouping: sessions) { time.day(of: $0.endedAt) }.mapValues { $0.reduce(0) { $0 + $1.actualSeconds } }
        return range.days.map { DailyFocus(date: $0, seconds: byDay[$0] ?? 0) }
    }

    private func categoryFocus(_ sessions: [FocusSession], total: Int) -> [CategoryFocus] {
        Dictionary(grouping: sessions, by: \.categoryId)
            .map { categoryId, group in
                let seconds = group.reduce(0) { $0 + $1.actualSeconds }
                let category = tasks.category(id: categoryId)
                return CategoryFocus(
                    categoryId: categoryId,
                    name: category?.name ?? "No category",
                    color: category?.color ?? .purple,
                    seconds: seconds,
                    share: total > 0 ? Double(seconds) / Double(total) : 0
                )
            }
            .sorted { $0.seconds > $1.seconds }
    }

    private func habitConsistency(in range: DateRange) -> [HabitConsistency] {
        habits.allHabits
            .map { habit in
                let done = habits.doneDays(of: habit)
                let scheduled = range.days.filter { habit.schedule.isScheduled(on: $0) }
                return HabitConsistency(habit: habit, completedDays: scheduled.filter(done.contains).count, scheduledDays: scheduled.count)
            }
            .filter { $0.scheduledDays > 0 }
            .sorted { $0.rate > $1.rate }
    }
}
