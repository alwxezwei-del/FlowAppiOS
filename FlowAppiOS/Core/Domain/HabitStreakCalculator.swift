import Foundation

/**
 * Habit streaks and consistency.
 */
struct HabitStreaks: Hashable {
    /** current streak of completed scheduled days */
    var current = 0
    /** longest streak ever */
    var longest = 0
    var completedDays = 0
    var scheduledDays = 0

    var completionRate: Double { scheduledDays <= 0 ? 0 : Double(completedDays) / Double(scheduledDays) }
}

/**
 * Calculates habit streaks from completions
 *
 * Rules:
 * - only scheduled days count; missing an unscheduled day doesn't break the streak;
 * - a day counts if completions >= daily target;
 * - an unfinished today doesn't break the streak
 */
struct HabitStreakCalculator {
    let timeProvider: TimeProvider

    /**
     * - Parameter completions: any order
     * - Parameter today: reference day, defaults to today
     */
    func calculate(habit: Habit, completions: [HabitCompletion], today: LocalDate? = nil) -> HabitStreaks {
        let today = today ?? timeProvider.today()
        let doneDays = doneDays(of: habit, completions: completions)

        let createdDate = timeProvider.localDate(of: habit.createdAt)
        let firstDay = min(createdDate, completions.map(\.date).min() ?? createdDate)
        if firstDay > today { return HabitStreaks() }

        var longest = 0
        var running = 0
        var scheduledDays = 0
        var completedDays = 0

        var day = firstDay
        while day <= today {
            if habit.schedule.isScheduled(on: day) {
                scheduledDays += 1
                if doneDays.contains(day) {
                    completedDays += 1
                    running += 1
                    longest = max(longest, running)
                } else {
                    running = 0
                }
            }
            day = day.plusDays(1)
        }

        return HabitStreaks(
            current: currentStreak(habit: habit, doneDays: doneDays, today: today),
            longest: longest,
            completedDays: completedDays,
            scheduledDays: scheduledDays
        )
    }

    func doneDays(of habit: Habit, completions: [HabitCompletion]) -> Set<LocalDate> {
        Set(Dictionary(grouping: completions, by: \.date).filter { $0.value.count >= habit.targetPerDay }.keys)
    }

    /**
     * Current streak
     */
    private func currentStreak(habit: Habit, doneDays: Set<LocalDate>, today: LocalDate) -> Int {
        var day = today
        if habit.schedule.isScheduled(on: day) && !doneDays.contains(day) {
            day = day.minusDays(1)
        }

        var streak = 0
        var checkedDays = 0
        while checkedDays < 3650 {
            if habit.schedule.isScheduled(on: day) {
                if !doneDays.contains(day) { break }
                streak += 1
            }
            day = day.minusDays(1)
            checkedDays += 1
        }
        return streak
    }
}

extension FlowDatabase {
    /**
     * Streaks for all habits
     *
     * - Returns: streaks by habit id
     */
    func habitStreaks(calculator: HabitStreakCalculator) -> [String: HabitStreaks] {
        let byHabit = Dictionary(grouping: completions, by: \.habitId)
        return Dictionary(uniqueKeysWithValues: habits.map { habit in
            (habit.id, calculator.calculate(habit: habit, completions: byHabit[habit.id] ?? []))
        })
    }
}
