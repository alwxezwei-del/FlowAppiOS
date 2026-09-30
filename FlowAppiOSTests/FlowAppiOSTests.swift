import Foundation
import Testing
@testable import FlowAppiOS

/**
 * - Parameter today: date seen by the calculator instead of the system one
 */
struct FixedTimeProvider: TimeProvider {
    let today: LocalDate

    func now() -> Date { instant(today) }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

func instant(_ date: LocalDate) -> Date { Date(timeIntervalSince1970: TimeInterval(date.epochDay) * 86_400) }

private let today = LocalDate(year: 2026, month: 9, day: 30)

struct LocalDateTests {
    @Test func epochDayRoundTrip() {
        #expect(LocalDate(year: 1970, month: 1, day: 1).epochDay == 0)
        #expect(today.year == 2026 && today.month == 9 && today.day == 30)
        #expect(LocalDate(year: 2024, month: 2, day: 29).plusDays(1) == LocalDate(year: 2024, month: 3, day: 1))
    }

    @Test func dayOfWeek() {
        // 30.09.2026 is Wednesday
        #expect(today.dayOfWeek == .wednesday)
        #expect(LocalDate(year: 1970, month: 1, day: 1).dayOfWeek == .thursday)
    }

    @Test func monthArithmeticClampsTheDay() {
        #expect(LocalDate(year: 2026, month: 1, day: 31).plusMonths(1) == LocalDate(year: 2026, month: 2, day: 28))
        #expect(LocalDate(year: 2026, month: 1, day: 15).plusMonths(-1) == LocalDate(year: 2025, month: 12, day: 15))
    }

    @Test func startOfWeekFollowsTheSetting() {
        #expect(today.startOfWeek(.monday) == LocalDate(year: 2026, month: 9, day: 28))
        #expect(today.startOfWeek(.sunday) == LocalDate(year: 2026, month: 9, day: 27))
    }
}

/**
 * Streak calculation tests: unfinished today, unscheduled days, partial daily target, empty
 * schedule.
 */
struct HabitStreakCalculatorTests {
    private let calculator = HabitStreakCalculator(timeProvider: FixedTimeProvider(today: today))

    @Test func noCompletionsMeansNoStreak() {
        let streaks = calculator.calculate(habit: dailyHabit(createdAt: today.minusDays(10)), completions: [], today: today)
        #expect(streaks.current == 0)
        #expect(streaks.longest == 0)
    }

    @Test func consecutiveDaysBuildTheCurrentStreak() {
        let habit = dailyHabit(createdAt: today.minusDays(5))
        let streaks = calculator.calculate(habit: habit, completions: completions(habit, today, today.minusDays(1), today.minusDays(2)), today: today)
        #expect(streaks.current == 3)
        #expect(streaks.longest == 3)
    }

    @Test func anUnfinishedTodayDoesNotBreakTheStreak() {
        // Morning: today isn't done yet, but the two previous days are, so the streak holds
        let habit = dailyHabit(createdAt: today.minusDays(5))
        let streaks = calculator.calculate(habit: habit, completions: completions(habit, today.minusDays(1), today.minusDays(2)), today: today)
        #expect(streaks.current == 2)
    }

    @Test func aMissedDayResetsTheCurrentStreakButKeepsTheLongest() {
        let habit = dailyHabit(createdAt: today.minusDays(10))
        let done = completions(
            habit,
            today.minusDays(9),
            today.minusDays(8),
            today.minusDays(7),
            today.minusDays(6),
            // Missed five days ago
            today
        )
        let streaks = calculator.calculate(habit: habit, completions: done, today: today)
        #expect(streaks.current == 1)
        #expect(streaks.longest == 4)
    }

    @Test func daysOutsideTheScheduleDoNotBreakTheStreak() {
        // Mon, Wed, Fri: weekends are skipped by schedule, not by the user
        let habit = Habit(id: "habit", name: "Workout", icon: "workout", schedule: .selectedDays([.monday, .wednesday, .friday]), createdAt: instant(today.minusDays(14)))
        // 30.09.2026 is Wednesday; previous scheduled days are Mon 28th and Fri 25th
        let streaks = calculator.calculate(habit: habit, completions: completions(habit, today, today.minusDays(2), today.minusDays(5)), today: today)
        #expect(streaks.current == 3)
    }

    @Test func aDayCountsOnlyWhenTheDailyTargetIsReached() {
        let habit = dailyHabit(createdAt: today.minusDays(3), targetPerDay: 2)
        let done = completions(habit, today.minusDays(1), today.minusDays(1)) +
            // Today's target is half done, so the day doesn't count
            completions(habit, today)
        #expect(calculator.calculate(habit: habit, completions: done, today: today).current == 1)
    }

    @Test func completionRateCountsOnlyScheduledDays() {
        let habit = dailyHabit(createdAt: today.minusDays(3))
        let streaks = calculator.calculate(habit: habit, completions: completions(habit, today, today.minusDays(1)), today: today)
        // Four scheduled days: today and three previous
        #expect(streaks.scheduledDays == 4)
        #expect(streaks.completedDays == 2)
        #expect(streaks.completionRate == 0.5)
    }

    @Test func anEmptyScheduleProducesNoStreakInsteadOfLoopingForever() {
        let habit = Habit(id: "habit", name: "Never", icon: "star", schedule: .selectedDays([]), createdAt: instant(today.minusDays(5)))
        let streaks = calculator.calculate(habit: habit, completions: [], today: today)
        #expect(streaks.current == 0)
        #expect(streaks.scheduledDays == 0)
    }

    @Test func aHabitCreatedInTheFutureHasNoHistory() {
        #expect(calculator.calculate(habit: dailyHabit(createdAt: today.plusDays(3)), completions: [], today: today).scheduledDays == 0)
    }

    private func dailyHabit(createdAt: LocalDate, targetPerDay: Int = 1) -> Habit {
        Habit(id: "habit", name: "Read", icon: "read", targetPerDay: targetPerDay, createdAt: instant(createdAt))
    }

    private func completions(_ habit: Habit, _ dates: LocalDate...) -> [HabitCompletion] {
        dates.map { HabitCompletion(habitId: habit.id, date: $0, completedAt: instant($0)) }
    }
}

/** Timer math tests. State is timestamp-based, so everything is pure functions. */
struct TimerStateTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private var session: RunningSession { RunningSession(id: "session", plannedSeconds: 25 * 60, startedAt: start) }

    @Test func idleTimerHasNoElapsedTime() {
        #expect(TimerState.idle.elapsed(at: start + 600) == 0)
    }

    @Test func runningTimerAddsTimeAccumulatedBeforeThePause() {
        let state = TimerState.running(session: session, startedAt: start + 300, accumulated: 180)
        #expect(state.elapsed(at: start + 420) == 300)
    }

    @Test func pausedTimerDoesNotAdvance() {
        #expect(TimerState.paused(session: session, accumulated: 480).elapsed(at: start + 1800) == 480)
    }

    @Test func remainingTimeNeverGoesBelowZero() {
        let state = TimerState.running(session: session, startedAt: start, accumulated: 0)
        #expect(state.remaining(at: start + 2400) == 0)
        #expect(state.remaining(at: start + 300) == 1200)
    }

    @Test func progressIsAFractionCappedAtOne() {
        let state = TimerState.running(session: session, startedAt: start, accumulated: 0)
        #expect(abs(state.progress(at: start + 300) - 0.2) < 0.0001)
        #expect(state.progress(at: start + 3600) == 1)
    }
}

/** Statistics aggregation tests: the summary is derived from the same data as other screens. */
@MainActor
struct StatisticsTests {
    // Wednesday, mid-week: shows the week starts from the configured first day, not from the date
    private let timeProvider = FixedTimeProvider(today: today)

    @Test func focusTimeIsSummedOnlyOverTheSelectedPeriod() {
        let summary = summary(sessions: [
            session(60, today),
            session(30, today.minusDays(1)),
            // Outside the week: last week's Monday
            session(45, today.minusDays(9)),
        ])
        #expect(summary.totalFocusSeconds == 90 * 60)
    }

    @Test func breaksAreExcludedFromFocusedTime() {
        let summary = summary(sessions: [session(25, today), session(5, today, kind: .shortBreak), session(15, today, kind: .longBreak)])
        #expect(summary.totalFocusSeconds == 25 * 60)
    }

    @Test func theChartHasOnePointPerDayIncludingEmptyOnes() {
        let summary = summary(sessions: [session(20, today)])
        #expect(summary.dailyFocus.count == 7)
        #expect(summary.dailyFocus.first { $0.date == today }?.seconds == 20 * 60)
        #expect(summary.dailyFocus.first { $0.date == today.minusDays(1) }?.seconds == 0)
    }

    @Test func theWeekStartsOnTheDayChosenInSettings() {
        // 30.09.2026 is Wednesday, the previous Sunday is the 27th
        #expect(summary(startOfWeek: .sunday).range.start == LocalDate(year: 2026, month: 9, day: 27))
    }

    @Test func focusIsSplitByCategoryAndUncategorizedIsKept() {
        let work = Category(id: "work", name: "Work", color: .purple, icon: "work")
        let summary = summary(categories: [work], sessions: [session(60, today, categoryId: "work"), session(20, today)])
        #expect(summary.categories.map(\.categoryName) == ["Work", "No category"])
        #expect(summary.categories.first?.share == 0.75)
    }

    @Test func taskCompletionCountsOnlyTasksOfThePeriod() {
        let summary = summary(tasks: [
            task(today, .completed),
            task(today, .active),
            task(today.minusDays(9), .completed),
            // Archived tasks are excluded from the completion rate
            task(today, .archived),
        ])
        #expect(summary.completedTasks == 1)
        #expect(summary.totalTasks == 2)
    }

    @Test func habitConsistencyCountsScheduledDaysOfThePeriod() {
        let habit = Habit(id: "habit", name: "Workout", icon: "workout", schedule: .selectedDays([.monday, .wednesday]), createdAt: Date(timeIntervalSince1970: 0))
        let monday = today.minusDays(2)
        let summary = summary(habits: [habit], completions: [HabitCompletion(habitId: habit.id, date: monday, completedAt: instant(monday))])
        let consistency = summary.habits.first
        #expect(consistency?.scheduledDays == 2)
        #expect(consistency?.completedDays == 1)
    }

    @Test func theTrendComparesThePeriodWithThePreviousOne() {
        let trend = summary(sessions: [
            session(120, today),
            // Last week: Tuesday
            session(60, today.minusDays(8)),
        ]).focusTrend
        #expect(trend == 1)
        #expect(summary(sessions: [session(30, today)]).focusTrend == nil)
    }

    private func summary(
        startOfWeek: DayOfWeek = .monday,
        categories: [FlowAppiOS.Category] = [],
        sessions: [FocusSession] = [],
        tasks: [FlowTask] = [],
        habits: [Habit] = [],
        completions: [HabitCompletion] = []
    ) -> StatisticsSummary {
        let database = FlowDatabase(fileURL: nil, timeProvider: timeProvider)
        database.replaceAll(with: DatabaseDto(
            categories: categories.map(\.dto),
            tasks: tasks.map(\.dto),
            habits: habits.map(\.dto),
            habitCompletions: completions.map(\.dto),
            focusSessions: sessions.map(\.dto)
        ))
        return database.statistics(period: .week, startOfWeek: startOfWeek, timeProvider: timeProvider)
    }

    private func session(_ minutes: Int, _ endedAt: LocalDate, kind: FocusKind = .focus, categoryId: String? = nil) -> FocusSession {
        FocusSession(categoryId: categoryId, kind: kind, plannedSeconds: minutes * 60, actualSeconds: minutes * 60, startedAt: instant(endedAt), endedAt: instant(endedAt), completed: true)
    }

    private func task(_ dueDate: LocalDate, _ status: TaskStatus) -> FlowTask {
        FlowTask(title: "Task", dueDate: dueDate, status: status, createdAt: instant(dueDate))
    }
}

@MainActor
struct FocusTimerControllerTests {
    @Test func finishingAFocusSessionSavesItAndCompletesTheTask() {
        let clock = MutableClock(now: instant(today))
        let defaults = UserDefaults(suiteName: "timer-test-\(UUID())")!
        let database = FlowDatabase(fileURL: nil, timeProvider: clock)
        let task = FlowTask(title: "Write", estimateSeconds: 600, createdAt: clock.now())
        database.createTask(task)
        let controller = FocusTimerController(store: TimerStateStore(defaults: defaults), database: database, notifications: FocusNotifications(), timeProvider: clock)

        controller.start(RunningSession(taskId: task.id, taskTitle: task.title, plannedSeconds: 600, startedAt: clock.now()))
        clock.current += 700
        let session = controller.finishIfElapsed()

        #expect(session?.actualSeconds == 600)
        #expect(session?.completed == true)
        #expect(controller.state == .idle)
        #expect(database.task(id: task.id)?.status == .completed)
        #expect(database.task(id: task.id)?.focusedSeconds == 600)
    }

    @Test func accidentalShortSessionsAreDiscarded() {
        let clock = MutableClock(now: instant(today))
        let database = FlowDatabase(fileURL: nil, timeProvider: clock)
        let controller = FocusTimerController(store: TimerStateStore(defaults: UserDefaults(suiteName: "timer-test-\(UUID())")!), database: database, notifications: FocusNotifications(), timeProvider: clock)

        controller.start(RunningSession(plannedSeconds: 600, startedAt: clock.now()))
        clock.current += 3
        #expect(controller.stop(completed: false) == nil)
        #expect(database.sessions.isEmpty)
    }
}

final class MutableClock: TimeProvider {
    var current: Date

    init(now: Date) { current = now }

    func now() -> Date { current }

    var calendar: Calendar { FixedTimeProvider(today: LocalDate(epochDay: 0)).calendar }
}

/** Backup files are shared with the Android app */
@MainActor
struct BackupTests {
    @Test func importsAnAndroidExport() throws {
        let clock = FixedTimeProvider(today: today)
        let database = FlowDatabase(fileURL: nil, timeProvider: clock)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "backup-test-\(UUID())")!)
        let backup = BackupRepository(database: database, settingsStore: settings, timeProvider: clock)

        let result = backup.import(Self.androidExport)

        #expect(result == .success(tasks: 1, habits: 1, sessions: 1))
        #expect(settings.settings.themeMode == .dark)
        #expect(settings.settings.startOfWeek == .sunday)
        #expect(database.task(id: "t1")?.dueDate == LocalDate(epochDay: 20361))
        #expect(database.task(id: "t1")?.estimateSeconds == 2700)
        #expect(database.habit(id: "h1")?.schedule == .selectedDays([.monday, .wednesday]))
        #expect(database.completions(habitId: "h1").count == 1)
        #expect(database.sessions.first?.kind == .shortBreak)
    }

    @Test func exportRoundTrips() throws {
        let clock = FixedTimeProvider(today: today)
        let database = FlowDatabase(fileURL: nil, timeProvider: clock)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "backup-test-\(UUID())")!)
        let backup = BackupRepository(database: database, settingsStore: settings, timeProvider: clock)
        _ = backup.import(Self.androidExport)

        let json = try backup.export()
        backup.reset()
        #expect(database.tasks.isEmpty)

        #expect(backup.import(json) == .success(tasks: 1, habits: 1, sessions: 1))
        #expect(database.task(id: "t1")?.title == "Finish navigation")
    }

    @Test func rejectsForeignAndNewerFiles() {
        let clock = FixedTimeProvider(today: today)
        let backup = BackupRepository(
            database: FlowDatabase(fileURL: nil, timeProvider: clock),
            settingsStore: SettingsStore(defaults: UserDefaults(suiteName: "backup-test-\(UUID())")!),
            timeProvider: clock
        )
        #expect(backup.import("{\"hello\": 1}") == .invalidFile)
        #expect(backup.import(Self.androidExport.replacingOccurrences(of: "\"version\": 1", with: "\"version\": 7")) == .unsupportedVersion(fileVersion: 7, supportedVersion: 1))
    }

    private static let androidExport = """
    {
        "version": 1,
        "exported_at": 1790000000000,
        "settings": {
            "theme_mode": "dark",
            "accent_color": "teal",
            "focus_minutes": 45,
            "short_break_minutes": 5,
            "long_break_minutes": 15,
            "start_of_week": 6,
            "notifications_enabled": true
        },
        "categories": [
            { "id": "work", "name": "Work", "color": "purple", "icon": "work", "sort_order": 0 }
        ],
        "tasks": [
            {
                "id": "t1", "title": "Finish navigation", "description": null, "category_id": "work",
                "estimate_seconds": 2700, "focused_seconds": 600, "due_date": 20361,
                "priority": "high", "status": "active", "created_at": 1790000000000, "completed_at": null
            }
        ],
        "habits": [
            {
                "id": "h1", "name": "Workout", "icon": "workout", "color": "green",
                "schedule_type": "selected_days", "schedule_days_mask": 5, "target_per_day": 1,
                "reminder_minute_of_day": 1140, "note": null, "created_at": 1790000000000,
                "archived": false, "sort_order": 0
            }
        ],
        "habit_completions": [
            { "id": "c1", "habit_id": "h1", "date": 20361, "completed_at": 1790000000000 }
        ],
        "focus_sessions": [
            {
                "id": "s1", "task_id": "t1", "category_id": "work", "kind": "short_break",
                "planned_seconds": 300, "actual_seconds": 300, "started_at": 1790000000000,
                "ended_at": 1790000300000, "completed": true
            }
        ]
    }
    """
}
