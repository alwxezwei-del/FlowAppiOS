import Foundation

// Models are stored with the same JSON shape as the Android app (snake_case keys via the coder,
// dates in epoch millis, days in epoch days), so backups move between platforms as is.

func newId() -> String { UUID().uuidString.lowercased() }

/// String enum that decodes unknown values to a fallback instead of failing the whole file.
protocol LenientEnum: RawRepresentable, Codable, CaseIterable, Hashable where RawValue == String {
    static var fallback: Self { get }
}

extension LenientEnum {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .fallback
    }
}

enum AccentColor: String, LenientEnum {
    case purple, violet, blue, teal, green, orange, pink
    static let fallback = AccentColor.purple
}

enum TaskStatus: String, LenientEnum {
    case active, completed, archived
    static let fallback = TaskStatus.active
}

enum Priority: String, LenientEnum {
    case low, medium, high
    static let fallback = Priority.medium

    /// Higher goes first when sorting by priority.
    var weight: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }
}

enum FocusKind: String, LenientEnum {
    case focus
    case shortBreak = "short_break"
    case longBreak = "long_break"
    static let fallback = FocusKind.focus
}

enum ThemeMode: String, LenientEnum {
    case system, light, dark
    static let fallback = ThemeMode.system
}

/// Icon keys shared with Android. The picker shows them in this order.
enum IconKey {
    static let all = ["workout", "read", "code", "meditate", "heart", "star", "water", "walk", "work", "learning", "personal", "health"]
    static let fallback = "star"
}

struct Category: Identifiable, Hashable, Codable {
    var id = newId()
    var name: String
    var color: AccentColor
    var icon: String
    var sortOrder = 0
}

struct FlowTask: Identifiable, Hashable, Codable {
    var id = newId()
    var title: String
    var description: String?
    var categoryId: String?
    var estimateSeconds: Int?
    /// Added up from focus sessions linked to the task, never edited by hand.
    var focusedSeconds = 0
    var dueDate: LocalDate?
    var priority = Priority.medium
    var status = TaskStatus.active
    var createdAt: Date
    var completedAt: Date?

    var isCompleted: Bool { status == .completed }

    /// Share of the estimate already focused. A task without an estimate counts as done once any time is logged.
    var focusProgress: Double {
        guard focusedSeconds > 0 else { return 0 }
        guard let estimateSeconds, estimateSeconds > 0 else { return 1 }
        return min(Double(focusedSeconds) / Double(estimateSeconds), 1)
    }
}

enum HabitSchedule: Hashable {
    case daily
    case selectedDays(Set<DayOfWeek>)

    func isScheduled(on date: LocalDate) -> Bool {
        switch self {
        case .daily: true
        case .selectedDays(let days): days.contains(date.dayOfWeek)
        }
    }
}

struct Habit: Identifiable, Hashable {
    var id = newId()
    var name: String
    var icon: String
    var color = AccentColor.purple
    var schedule = HabitSchedule.daily
    var targetPerDay = 1
    /// Minutes since midnight.
    var reminderMinuteOfDay: Int?
    var note: String?
    var createdAt: Date
    var archived = false
    var sortOrder = 0
}

extension Habit: Codable {
    // Android stores the schedule as a type plus a weekday bitmask, Monday being the lowest bit
    private enum CodingKeys: String, CodingKey {
        case id, name, icon, color, scheduleType, scheduleDaysMask, targetPerDay, reminderMinuteOfDay, note, createdAt, archived, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        color = try c.decode(AccentColor.self, forKey: .color)
        if try c.decode(String.self, forKey: .scheduleType) == "selected_days" {
            let mask = try c.decode(Int.self, forKey: .scheduleDaysMask)
            schedule = .selectedDays(Set(DayOfWeek.allCases.filter { mask & (1 << $0.rawValue) != 0 }))
        } else {
            schedule = .daily
        }
        targetPerDay = max(try c.decode(Int.self, forKey: .targetPerDay), 1)
        reminderMinuteOfDay = try c.decodeIfPresent(Int.self, forKey: .reminderMinuteOfDay)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        archived = try c.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(icon, forKey: .icon)
        try c.encode(color, forKey: .color)
        switch schedule {
        case .daily:
            try c.encode("daily", forKey: .scheduleType)
            try c.encode(0b111_1111, forKey: .scheduleDaysMask)
        case .selectedDays(let days):
            try c.encode("selected_days", forKey: .scheduleType)
            try c.encode(days.reduce(0) { $0 | (1 << $1.rawValue) }, forKey: .scheduleDaysMask)
        }
        try c.encode(targetPerDay, forKey: .targetPerDay)
        try c.encode(reminderMinuteOfDay, forKey: .reminderMinuteOfDay)
        try c.encode(note, forKey: .note)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(archived, forKey: .archived)
        try c.encode(sortOrder, forKey: .sortOrder)
    }
}

struct HabitCompletion: Identifiable, Hashable, Codable {
    var id = newId()
    var habitId: String
    /// The day it counts for, which can differ from `completedAt` when filling in past days.
    var date: LocalDate
    var completedAt: Date
}

struct FocusSession: Identifiable, Hashable, Codable {
    var id = newId()
    var taskId: String?
    /// Copied from the task when the session ends, so stats don't change if the task is recategorized.
    var categoryId: String?
    var kind = FocusKind.focus
    var plannedSeconds: Int
    /// Time actually spent, pauses excluded.
    var actualSeconds: Int
    var startedAt: Date
    var endedAt: Date
    /// The timer ran out rather than being stopped.
    var completed: Bool
}

struct AppSettings: Hashable, Codable {
    var themeMode = ThemeMode.system
    var accentColor = AccentColor.purple
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var startOfWeek = DayOfWeek.monday
    var notificationsEnabled = true
}

/// A timer that is running or paused. Time is derived from timestamps, so it survives the app being killed.
struct ActiveSession: Hashable, Codable {
    var id = newId()
    var taskId: String?
    var taskTitle: String?
    var categoryId: String?
    var kind = FocusKind.focus
    var plannedSeconds: Int
    var startedAt: Date
    /// When the timer was last started or resumed. `nil` while paused.
    var resumedAt: Date?
    /// Time run before the last pause.
    var accumulated: TimeInterval = 0

    var isRunning: Bool { resumedAt != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (resumedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    func remaining(at now: Date) -> TimeInterval {
        max(TimeInterval(plannedSeconds) - elapsed(at: now), 0)
    }

    func progress(at now: Date) -> Double {
        plannedSeconds > 0 ? min(max(elapsed(at: now) / TimeInterval(plannedSeconds), 0), 1) : 0
    }
}
