import Foundation
import Observation

/// Habits, their daily completions and streaks.
@MainActor
@Observable
final class HabitService {
    private(set) var habits: [Habit] = []
    private(set) var completions: [HabitCompletion] = []

    @ObservationIgnored private let file: JSONFile<Stored>
    @ObservationIgnored private let time: TimeSource

    private struct Stored: Codable {
        var habits: [Habit]
        var habitCompletions: [HabitCompletion]
    }

    init(time: TimeSource, fileName: String? = "habits.json") {
        self.time = time
        file = JSONFile(fileName)
        if let stored = file.load() {
            habits = stored.habits
            completions = stored.habitCompletions
        }
    }

    // MARK: Queries

    /// Active first, then by sort order and name.
    var allHabits: [Habit] {
        habits.sorted { a, b in
            a.archived != b.archived ? !a.archived : (a.sortOrder, a.name) < (b.sortOrder, b.name)
        }
    }

    var activeHabits: [Habit] { allHabits.filter { !$0.archived } }

    func habit(id: String?) -> Habit? {
        habits.first { $0.id == id }
    }

    func habits(scheduledOn date: LocalDate) -> [Habit] {
        activeHabits.filter { $0.schedule.isScheduled(on: date) }
    }

    func completedCount(_ habit: Habit, on date: LocalDate) -> Int {
        completions.filter { $0.habitId == habit.id && $0.date == date }.count
    }

    func isDone(_ habit: Habit, on date: LocalDate) -> Bool {
        completedCount(habit, on: date) >= habit.targetPerDay
    }

    /// Days where the daily target was reached.
    func doneDays(of habit: Habit) -> Set<LocalDate> {
        let perDay = Dictionary(grouping: completions.filter { $0.habitId == habit.id }, by: \.date)
        return Set(perDay.filter { $0.value.count >= habit.targetPerDay }.keys)
    }

    /// Only scheduled days count, so skipping a day off never breaks a streak.
    /// Today not being done yet doesn't break it either.
    func streaks(for habit: Habit, today: LocalDate? = nil) -> HabitStreaks {
        let today = today ?? time.today
        let done = doneDays(of: habit)
        let created = time.day(of: habit.createdAt)
        let firstDay = min(created, completions.filter { $0.habitId == habit.id }.map(\.date).min() ?? created)
        guard firstDay <= today else { return HabitStreaks() }

        var result = HabitStreaks()
        var run = 0
        for day in DateRange(start: firstDay, end: today).days where habit.schedule.isScheduled(on: day) {
            result.scheduledDays += 1
            if done.contains(day) {
                result.completedDays += 1
                run += 1
                result.longest = max(result.longest, run)
            } else {
                run = 0
            }
        }

        var day = habit.schedule.isScheduled(on: today) && !done.contains(today) ? today.minusDays(1) : today
        // The cap keeps a habit with no scheduled days from looping forever
        for _ in 0..<3650 {
            if habit.schedule.isScheduled(on: day) {
                guard done.contains(day) else { break }
                result.current += 1
            }
            day = day.minusDays(1)
        }
        return result
    }

    // MARK: Changes

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func update(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        save()
    }

    /// Marks one more completion for the day, or takes back the latest one.
    func setDone(_ habitId: String, on date: LocalDate, _ done: Bool) {
        if done {
            completions.append(HabitCompletion(habitId: habitId, date: date, completedAt: time.now()))
        } else if let latest = completions.filter({ $0.habitId == habitId && $0.date == date }).max(by: { $0.completedAt < $1.completedAt }) {
            completions.removeAll { $0.id == latest.id }
        }
        save()
    }

    func setArchived(_ habitId: String, _ archived: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }
        habits[index].archived = archived
        save()
    }

    func delete(_ habitId: String) {
        habits.removeAll { $0.id == habitId }
        completions.removeAll { $0.habitId == habitId }
        save()
    }

    func replaceAll(habits: [Habit], completions: [HabitCompletion]) {
        self.habits = habits
        self.completions = completions
        save()
    }

    private func save() {
        file.save(Stored(habits: habits, habitCompletions: completions))
    }
}
