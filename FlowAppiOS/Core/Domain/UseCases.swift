import Foundation

/**
 * Today screen data for a single day
 */
struct TodaySnapshot {
    let date: LocalDate
    var tasks: [FlowTask] = []
    var habits: [HabitDayProgress] = []
    var categories: [Category] = []
    var focusTodaySeconds = 0
    /** used for the comparison line */
    var focusYesterdaySeconds = 0

    var completedTasks: Int { tasks.filter { $0.status == .completed }.count }

    /** Non archived tasks count */
    var totalTasks: Int { tasks.filter { $0.status != .archived }.count }

    /** Focus time change vs yesterday as a fraction */
    var focusTrend: Double? {
        guard focusYesterdaySeconds > 0 else { return nil }
        return Double(focusTodaySeconds - focusYesterdaySeconds) / Double(focusYesterdaySeconds)
    }
}

@MainActor
extension FlowDatabase {
    /** Combines tasks, habits, categories and focus time into a Today snapshot */
    func today(_ date: LocalDate) -> TodaySnapshot {
        let yesterday = date.minusDays(1)
        return TodaySnapshot(
            date: date,
            tasks: tasks(for: date),
            habits: habitProgress(for: date),
            categories: sortedCategories,
            focusTodaySeconds: totalFocusSeconds(in: DateRange(start: date, endInclusive: date)),
            focusYesterdaySeconds: totalFocusSeconds(in: DateRange(start: yesterday, endInclusive: yesterday))
        )
    }

    /** History feed, built from tasks, habit completions and focus sessions sorted by time */
    func history(range: DateRange, filter: HistoryFilter) -> [HistoryEvent] {
        let rangeTasks = tasks(in: range)
        let tasksById = Dictionary(rangeTasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var events: [HistoryEvent] = []

        if filter == .all || filter == .tasks {
            for task in rangeTasks where task.status == .completed {
                let category = category(id: task.categoryId)
                events.append(.taskCompleted(
                    id: task.id,
                    timestamp: task.completedAt ?? task.createdAt,
                    title: task.title,
                    categoryName: category?.name,
                    color: category?.color ?? .default
                ))
            }
        }

        if filter == .all || filter == .habits {
            for completion in completions(in: range) {
                guard let habit = habit(id: completion.habitId) else { continue }
                events.append(.habitCompleted(
                    id: completion.id,
                    timestamp: completion.completedAt,
                    habitName: habit.name,
                    icon: habit.icon,
                    color: habit.color
                ))
            }
        }

        if filter == .all || filter == .focus {
            for session in sessions(in: range) {
                events.append(.focusFinished(
                    id: session.id,
                    timestamp: session.endedAt,
                    taskTitle: session.taskId.flatMap { tasksById[$0]?.title },
                    kind: session.kind,
                    seconds: session.actualSeconds,
                    completed: session.completed
                ))
            }
        }

        return events.sorted { $0.timestamp > $1.timestamp }
    }

    /** Builds the statistics summary */
    func statistics(period: StatisticsPeriod, startOfWeek: DayOfWeek, timeProvider: TimeProvider) -> StatisticsSummary {
        let range = statisticsRange(period: period, today: timeProvider.today(), startOfWeek: startOfWeek)
        let previous = previousRange(period: period, range: range)

        let focusSessions = sessions(in: range).filter { $0.kind == .focus }
        let totalFocus = focusSessions.reduce(0) { $0 + $1.actualSeconds }
        let rangeTasks = tasks(in: range)

        return StatisticsSummary(
            period: period,
            range: range,
            totalFocusSeconds: totalFocus,
            previousTotalFocusSeconds: totalFocusSeconds(in: previous),
            dailyFocus: dailyFocus(range: range, sessions: focusSessions, timeProvider: timeProvider),
            completedTasks: rangeTasks.filter { $0.status == .completed }.count,
            totalTasks: rangeTasks.filter { $0.status != .archived }.count,
            categories: categoryFocus(sessions: focusSessions, totalFocus: totalFocus),
            habits: habitConsistency(range: range)
        )
    }

    /** Explicit zeros for days */
    private func dailyFocus(range: DateRange, sessions: [FocusSession], timeProvider: TimeProvider) -> [DailyFocus] {
        let byDay = Dictionary(grouping: sessions) { timeProvider.localDate(of: $0.endedAt) }
            .mapValues { $0.reduce(0) { $0 + $1.actualSeconds } }
        return range.days.map { DailyFocus(date: $0, seconds: byDay[$0] ?? 0) }
    }

    private func categoryFocus(sessions: [FocusSession], totalFocus: Int) -> [CategoryFocus] {
        guard !sessions.isEmpty else { return [] }
        return Dictionary(grouping: sessions, by: \.categoryId)
            .map { categoryId, categorySessions in
                let seconds = categorySessions.reduce(0) { $0 + $1.actualSeconds }
                let category = category(id: categoryId)
                return CategoryFocus(
                    categoryId: categoryId,
                    categoryName: category?.name ?? "No category",
                    color: category?.color ?? .default,
                    seconds: seconds,
                    share: totalFocus <= 0 ? 0 : Double(seconds) / Double(totalFocus)
                )
            }
            .sorted { $0.seconds > $1.seconds }
    }

    private func habitConsistency(range: DateRange) -> [HabitConsistency] {
        let days = range.days
        let completionsByHabit = Dictionary(grouping: completions(in: range), by: \.habitId)

        return allHabits
            .map { habit in
                let doneDays = Set(Dictionary(grouping: completionsByHabit[habit.id] ?? [], by: \.date)
                    .filter { $0.value.count >= habit.targetPerDay }.keys)
                let scheduled = days.filter { habit.schedule.isScheduled(on: $0) }
                return HabitConsistency(
                    habitId: habit.id,
                    habitName: habit.name,
                    icon: habit.icon,
                    color: habit.color,
                    completedDays: scheduled.filter(doneDays.contains).count,
                    scheduledDays: scheduled.count
                )
            }
            .filter { $0.scheduledDays > 0 }
            .sorted { $0.rate > $1.rate }
    }
}
