import Foundation

/** Generates an id for a new domain entity */
func newId() -> String { UUID().uuidString.lowercased() }

/**
 * User selectable accent palette
 *
 * `rawValue` - stable key for DB and JSON export
 */
enum AccentColor: String, CaseIterable, Hashable {
    case purple, violet, blue, teal, green, orange, pink

    static let `default`: AccentColor = .purple

    /** Unknown values fall back to ``default``. */
    static func parse(_ key: String?) -> AccentColor { key.flatMap(AccentColor.init(rawValue:)) ?? .default }
}

/**
 * Icon keys for habits and categories
 */
enum FlowIconKey {
    static let workout = "workout"
    static let read = "read"
    static let code = "code"
    static let meditate = "meditate"
    static let heart = "heart"
    static let star = "star"
    static let water = "water"
    static let walk = "walk"
    static let work = "work"
    static let learning = "learning"
    static let personal = "personal"
    static let health = "health"

    /** All keys in icon picker order */
    static let all: [String] = [workout, read, code, meditate, heart, star, water, walk, work, learning, personal, health]

    static let `default` = star
}

/**
 * Task status
 *
 * `rawValue` - stable storage key
 */
enum TaskStatus: String, Hashable {
    case active, completed, archived

    static func parse(_ key: String?) -> TaskStatus { key.flatMap(TaskStatus.init(rawValue:)) ?? .active }
}

/**
 * Task priority
 */
enum Priority: String, CaseIterable, Hashable {
    case low, medium, high

    static let `default`: Priority = .medium

    /** sort weight, higher goes first */
    var weight: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func parse(_ key: String?) -> Priority { key.flatMap(Priority.init(rawValue:)) ?? .default }
}

/**
 * User category for tasks and habits
 */
struct Category: Identifiable, Hashable {
    var id: String = newId()
    var name: String
    var color: AccentColor
    /** key from ``FlowIconKey`` */
    var icon: String
    var sortOrder: Int = 0
}

/**
 * User task. ``focusedSeconds`` is accumulated from linked focus sessions, not edited manually
 */
struct FlowTask: Identifiable, Hashable {
    var id: String = newId()
    var title: String
    var description: String? = nil
    var categoryId: String? = nil
    /** planned duration, nil if not set */
    var estimateSeconds: Int? = nil
    var focusedSeconds: Int = 0
    /** nil = no due date */
    var dueDate: LocalDate? = nil
    var priority: Priority = .default
    var status: TaskStatus = .active
    var createdAt: Date
    /** not nil only for ``TaskStatus/completed`` */
    var completedAt: Date? = nil

    var isCompleted: Bool { status == .completed }

    var focusProgress: Double {
        if focusedSeconds <= 0 { return 0 }
        guard let estimateSeconds, estimateSeconds > 0 else { return 1 }
        return min(max(Double(focusedSeconds) / Double(estimateSeconds), 0), 1)
    }
}

/** Habit schedule */
enum HabitSchedule: Hashable {
    /** Every day */
    case daily
    /** Only on selected weekdays */
    case selectedDays(Set<DayOfWeek>)

    func isScheduled(on date: LocalDate) -> Bool {
        switch self {
        case .daily: true
        case .selectedDays(let days): days.contains(date.dayOfWeek)
        }
    }
}

/**
 * Habit with a schedule and daily target
 */
struct Habit: Identifiable, Hashable {
    var id: String = newId()
    var name: String
    var icon: String
    var color: AccentColor = .default
    var schedule: HabitSchedule = .daily
    /** completions required per day, min 1 */
    var targetPerDay: Int = 1
    /** minutes from midnight, nil = no reminder */
    var reminderMinuteOfDay: Int? = nil
    var note: String? = nil
    var createdAt: Date
    /** hidden from active lists, history kept */
    var archived: Bool = false
    var sortOrder: Int = 0
}

/**
 * Single habit completion
 */
struct HabitCompletion: Identifiable, Hashable {
    var id: String = newId()
    var habitId: String
    /** day the completion counts for */
    var date: LocalDate
    /** when the user marked it */
    var completedAt: Date
}

/** Habit progress for a specific day */
struct HabitDayProgress: Hashable {
    let habit: Habit
    let date: LocalDate
    let completedCount: Int
    let scheduled: Bool

    /** Daily target reached */
    var isDone: Bool { completedCount >= habit.targetPerDay }

    /** Daily target progress */
    var progress: Double {
        habit.targetPerDay <= 0 ? 0 : min(max(Double(completedCount) / Double(habit.targetPerDay), 0), 1)
    }
}

/**
 * Timer interval kind
 *
 * `rawValue` - stable storage key
 */
enum FocusKind: String, Hashable {
    /** Work interval */
    case focus
    case shortBreak = "short_break"
    case longBreak = "long_break"

    static func parse(_ key: String?) -> FocusKind { key.flatMap(FocusKind.init(rawValue:)) ?? .focus }
}

/**
 * Completed or stopped timer session. Saved on stop; stats use ``actualSeconds``.
 */
struct FocusSession: Identifiable, Hashable {
    var id: String = newId()
    /** nil for a free session */
    var taskId: String? = nil
    /** copied at session time so stats survive task changes */
    var categoryId: String? = nil
    var kind: FocusKind = .focus
    var plannedSeconds: Int
    /** run time excluding pauses */
    var actualSeconds: Int
    var startedAt: Date
    var endedAt: Date
    /** timer reached zero */
    var completed: Bool
}

/**
 * Theme mode
 *
 * `rawValue` - stable storage key
 */
enum ThemeMode: String, CaseIterable, Hashable {
    case system, light, dark

    static let `default`: ThemeMode = .system

    static func parse(_ key: String?) -> ThemeMode { key.flatMap(ThemeMode.init(rawValue:)) ?? .default }
}

/**
 * User settings
 */
struct AppSettings: Hashable {
    var themeMode: ThemeMode = .default
    var accentColor: AccentColor = .default
    var focusMinutes: Int = AppSettings.defaultFocusMinutes
    var shortBreakMinutes: Int = AppSettings.defaultShortBreakMinutes
    var longBreakMinutes: Int = AppSettings.defaultLongBreakMinutes
    /** used by calendar and statistics */
    var startOfWeek: DayOfWeek = .monday
    /** timer notifications and habit reminders */
    var notificationsEnabled: Bool = true

    static let defaultFocusMinutes = 25
    static let defaultShortBreakMinutes = 5
    static let defaultLongBreakMinutes = 15
}
