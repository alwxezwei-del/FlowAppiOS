import Foundation
import Testing
@testable import FlowAppiOS

/// Pinned clock in UTC. Starts at midnight of the given day.
final class TestTime: TimeSource {
    var current: Date

    init(_ date: LocalDate) {
        current = instant(date)
    }

    func now() -> Date { current }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

func instant(_ date: LocalDate) -> Date {
    Date(timeIntervalSince1970: TimeInterval(date.epochDay) * 86_400)
}

/// Wednesday, so week boundaries are visible in the tests.
let today = LocalDate(year: 2026, month: 9, day: 30)

@MainActor
func makeServices(time: TestTime = TestTime(today)) -> AppServices {
    AppServices(time: time, persistent: false)
}

struct LocalDateTests {
    @Test func convertsToAndFromCalendarDates() {
        #expect(LocalDate(year: 1970, month: 1, day: 1).epochDay == 0)
        #expect(today.year == 2026 && today.month == 9 && today.day == 30)
        #expect(LocalDate(year: 2024, month: 2, day: 29).plusDays(1) == LocalDate(year: 2024, month: 3, day: 1))
    }

    @Test func knowsTheDayOfWeek() {
        #expect(today.dayOfWeek == .wednesday)
        #expect(today.startOfWeek(.monday) == LocalDate(year: 2026, month: 9, day: 28))
        #expect(today.startOfWeek(.sunday) == LocalDate(year: 2026, month: 9, day: 27))
    }

    @Test func clampsTheDayWhenAddingMonths() {
        #expect(LocalDate(year: 2026, month: 1, day: 31).plusMonths(1) == LocalDate(year: 2026, month: 2, day: 28))
        #expect(LocalDate(year: 2026, month: 1, day: 15).plusMonths(-1) == LocalDate(year: 2025, month: 12, day: 15))
    }
}

@MainActor
struct StreakTests {
    let services = makeServices()

    @Test func consecutiveDaysBuildAStreak() {
        let habit = addHabit(createdDaysAgo: 5, doneDaysAgo: [0, 1, 2])
        let streaks = services.habits.streaks(for: habit)
        #expect(streaks.current == 3)
        #expect(streaks.longest == 3)
    }

    @Test func todayNotDoneYetKeepsTheStreak() {
        let habit = addHabit(createdDaysAgo: 5, doneDaysAgo: [1, 2])
        #expect(services.habits.streaks(for: habit).current == 2)
    }

    @Test func aMissedDayResetsTheCurrentStreakOnly() {
        let habit = addHabit(createdDaysAgo: 10, doneDaysAgo: [9, 8, 7, 6, 0])
        let streaks = services.habits.streaks(for: habit)
        #expect(streaks.current == 1)
        #expect(streaks.longest == 4)
    }

    @Test func daysOffDoNotBreakTheStreak() {
        // Mon, Wed, Fri; the previous scheduled days are Mon 28th and Fri 25th
        let habit = addHabit(createdDaysAgo: 14, doneDaysAgo: [0, 2, 5], schedule: .selectedDays([.monday, .wednesday, .friday]))
        #expect(services.habits.streaks(for: habit).current == 3)
    }

    @Test func aDayCountsOnlyWhenTheTargetIsReached() {
        // Yesterday twice, today once out of two
        let habit = addHabit(createdDaysAgo: 3, doneDaysAgo: [1, 1, 0], target: 2)
        #expect(services.habits.streaks(for: habit).current == 1)
    }

    @Test func completionRateCountsScheduledDays() {
        let habit = addHabit(createdDaysAgo: 3, doneDaysAgo: [0, 1])
        let streaks = services.habits.streaks(for: habit)
        #expect(streaks.scheduledDays == 4)
        #expect(streaks.completionRate == 0.5)
    }

    @Test func handlesEmptyAndFutureSchedules() {
        let never = addHabit(createdDaysAgo: 5, doneDaysAgo: [], schedule: .selectedDays([]))
        #expect(services.habits.streaks(for: never) == HabitStreaks())
        let future = addHabit(createdDaysAgo: -3, doneDaysAgo: [])
        #expect(services.habits.streaks(for: future).scheduledDays == 0)
    }

    private func addHabit(createdDaysAgo: Int, doneDaysAgo: [Int], schedule: HabitSchedule = .daily, target: Int = 1) -> Habit {
        let habit = Habit(name: "Read", icon: "read", schedule: schedule, targetPerDay: target, createdAt: instant(today.minusDays(createdDaysAgo)))
        services.habits.add(habit)
        for days in doneDaysAgo {
            services.habits.setDone(habit.id, on: today.minusDays(days), true)
        }
        return habit
    }
}

@MainActor
struct FocusTests {
    let time = TestTime(today)

    @Test func pausedTimeIsNotCounted() {
        let services = makeServices(time: time)
        services.focus.start(task: nil, kind: .focus, minutes: 25)
        time.current += 300
        services.focus.togglePause()
        time.current += 600
        #expect(services.focus.active?.elapsed(at: time.now()) == 300)
        services.focus.togglePause()
        time.current += 60
        #expect(services.focus.active?.remaining(at: time.now()) == TimeInterval(25 * 60 - 360))
    }

    @Test func finishedSessionCompletesItsTask() {
        let services = makeServices(time: time)
        let task = FlowTask(title: "Write", estimateSeconds: 600, createdAt: time.now())
        services.tasks.add(task)

        // A session with a task is always focus, even if a break was selected
        services.focus.start(task: task, kind: .shortBreak, minutes: 10)
        time.current += 700
        let session = services.focus.finishIfElapsed()

        #expect(session?.actualSeconds == 600)
        #expect(session?.kind == .focus)
        #expect(services.focus.active == nil)
        #expect(services.tasks.task(id: task.id)?.isCompleted == true)
    }

    @Test func accidentalTapsAreNotSaved() {
        let services = makeServices(time: time)
        services.focus.start(task: nil, kind: .focus, minutes: 25)
        time.current += 3
        #expect(services.focus.stop() == nil)
        #expect(services.focus.sessions.isEmpty)
    }
}

@MainActor
struct StatsTests {
    let services = makeServices()

    @Test func sumsFocusOfTheWeekWithoutBreaks() {
        addSession(60, daysAgo: 0)
        addSession(30, daysAgo: 1)
        addSession(45, daysAgo: 9)
        addSession(5, daysAgo: 0, kind: .shortBreak)
        let summary = services.stats.summary(for: .week)
        #expect(summary.focusSeconds == 90 * 60)
        #expect(summary.dailyFocus.count == 7)
    }

    @Test func weekStartsOnTheChosenDay() {
        services.settings.update { $0.startOfWeek = .sunday }
        #expect(services.stats.summary(for: .week).range.start == LocalDate(year: 2026, month: 9, day: 27))
    }

    @Test func splitsFocusByCategory() {
        let work = Category(name: "Work", color: .purple, icon: "work")
        services.tasks.replaceAll(categories: [work], tasks: [])
        addSession(60, daysAgo: 0, categoryId: work.id)
        addSession(20, daysAgo: 0)
        let categories = services.stats.summary(for: .week).categories
        #expect(categories.map(\.name) == ["Work", "No category"])
        #expect(categories.first?.share == 0.75)
    }

    @Test func completionRateIgnoresArchivedAndOtherWeeks() {
        for (daysAgo, status) in [(0, TaskStatus.completed), (0, .active), (9, .completed), (0, .archived)] {
            services.tasks.add(FlowTask(title: "Task", dueDate: today.minusDays(daysAgo), status: status, createdAt: instant(today)))
        }
        let summary = services.stats.summary(for: .week)
        #expect(summary.completedTasks == 1)
        #expect(summary.totalTasks == 2)
    }

    @Test func comparesWithThePreviousWeek() {
        addSession(120, daysAgo: 0)
        addSession(60, daysAgo: 8)
        #expect(services.stats.summary(for: .week).focusTrend == 1)
    }

    private func addSession(_ minutes: Int, daysAgo: Int, kind: FocusKind = .focus, categoryId: String? = nil) {
        let end = instant(today.minusDays(daysAgo))
        let session = FocusSession(categoryId: categoryId, kind: kind, plannedSeconds: minutes * 60, actualSeconds: minutes * 60, startedAt: end, endedAt: end, completed: true)
        services.focus.replaceAll(sessions: services.focus.sessions + [session])
    }
}

/// Backups have to stay compatible with the Android app.
@MainActor
struct BackupTests {
    let services = makeServices()

    @Test func importsAnAndroidExport() {
        #expect(services.backup.import(Data(Self.androidExport.utf8)) == .success(tasks: 1, habits: 1, sessions: 1))
        #expect(services.settings.settings.themeMode == .dark)
        #expect(services.settings.settings.startOfWeek == .sunday)

        let task = services.tasks.task(id: "t1")
        #expect(task?.dueDate == LocalDate(epochDay: 20361))
        #expect(task?.estimateSeconds == 2700)
        #expect(task?.createdAt == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(services.habits.habit(id: "h1")?.schedule == .selectedDays([.monday, .wednesday]))
        #expect(services.focus.sessions.first?.kind == .shortBreak)
    }

    @Test func exportRoundTrips() throws {
        _ = services.backup.import(Data(Self.androidExport.utf8))
        let exported = try services.backup.export()
        services.backup.reset()
        #expect(services.tasks.tasks.isEmpty)

        #expect(services.backup.import(exported) == .success(tasks: 1, habits: 1, sessions: 1))
        #expect(services.tasks.task(id: "t1")?.title == "Finish navigation")
    }

    @Test func rejectsForeignAndNewerFiles() {
        #expect(services.backup.import(Data("{\"hello\": 1}".utf8)) == .invalidFile)
        let newer = Self.androidExport.replacingOccurrences(of: "\"version\": 1", with: "\"version\": 7")
        #expect(services.backup.import(Data(newer.utf8)) == .unsupportedVersion(7))
    }

    static let androidExport = """
    {
        "version": 1,
        "exported_at": 1790000000000,
        "settings": {
            "theme_mode": "dark", "accent_color": "teal", "focus_minutes": 45, "short_break_minutes": 5,
            "long_break_minutes": 15, "start_of_week": 6, "notifications_enabled": true
        },
        "categories": [{ "id": "work", "name": "Work", "color": "purple", "icon": "work", "sort_order": 0 }],
        "tasks": [{
            "id": "t1", "title": "Finish navigation", "description": null, "category_id": "work",
            "estimate_seconds": 2700, "focused_seconds": 600, "due_date": 20361,
            "priority": "high", "status": "active", "created_at": 1790000000000, "completed_at": null
        }],
        "habits": [{
            "id": "h1", "name": "Workout", "icon": "workout", "color": "green",
            "schedule_type": "selected_days", "schedule_days_mask": 5, "target_per_day": 1,
            "reminder_minute_of_day": 1140, "note": null, "created_at": 1790000000000, "archived": false, "sort_order": 0
        }],
        "habit_completions": [{ "id": "c1", "habit_id": "h1", "date": 20361, "completed_at": 1790000000000 }],
        "focus_sessions": [{
            "id": "s1", "task_id": "t1", "category_id": "work", "kind": "short_break", "planned_seconds": 300,
            "actual_seconds": 300, "started_at": 1790000000000, "ended_at": 1790000300000, "completed": true
        }]
    }
    """
}
