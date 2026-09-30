import Foundation

struct BackupDto: Codable {
    var version: Int
    var exportedAt: Int64
    var settings: SettingsDto
    var categories: [CategoryDto] = []
    var tasks: [TaskDto] = []
    var habits: [HabitDto] = []
    var habitCompletions: [HabitCompletionDto] = []
    var focusSessions: [FocusSessionDto] = []

    static let currentVersion = 1

    enum CodingKeys: String, CodingKey {
        case version
        case exportedAt = "exported_at"
        case settings, categories, tasks, habits
        case habitCompletions = "habit_completions"
        case focusSessions = "focus_sessions"
    }

    init(version: Int, exportedAt: Int64, settings: SettingsDto, content: DatabaseDto) {
        self.version = version
        self.exportedAt = exportedAt
        self.settings = settings
        categories = content.categories
        tasks = content.tasks
        habits = content.habits
        habitCompletions = content.habitCompletions
        focusSessions = content.focusSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Int64.self, forKey: .exportedAt)
        settings = try container.decode(SettingsDto.self, forKey: .settings)
        categories = try container.decodeIfPresent([CategoryDto].self, forKey: .categories) ?? []
        tasks = try container.decodeIfPresent([TaskDto].self, forKey: .tasks) ?? []
        habits = try container.decodeIfPresent([HabitDto].self, forKey: .habits) ?? []
        habitCompletions = try container.decodeIfPresent([HabitCompletionDto].self, forKey: .habitCompletions) ?? []
        focusSessions = try container.decodeIfPresent([FocusSessionDto].self, forKey: .focusSessions) ?? []
    }

    var content: DatabaseDto {
        DatabaseDto(categories: categories, tasks: tasks, habits: habits, habitCompletions: habitCompletions, focusSessions: focusSessions)
    }
}

struct DatabaseDto: Codable {
    var categories: [CategoryDto] = []
    var tasks: [TaskDto] = []
    var habits: [HabitDto] = []
    var habitCompletions: [HabitCompletionDto] = []
    var focusSessions: [FocusSessionDto] = []

    enum CodingKeys: String, CodingKey {
        case categories, tasks, habits
        case habitCompletions = "habit_completions"
        case focusSessions = "focus_sessions"
    }
}

struct SettingsDto: Codable {
    var themeMode: String
    var accentColor: String
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var startOfWeek: Int
    var notificationsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case themeMode = "theme_mode"
        case accentColor = "accent_color"
        case focusMinutes = "focus_minutes"
        case shortBreakMinutes = "short_break_minutes"
        case longBreakMinutes = "long_break_minutes"
        case startOfWeek = "start_of_week"
        case notificationsEnabled = "notifications_enabled"
    }
}

struct CategoryDto: Codable {
    var id: String
    var name: String
    var color: String
    var icon: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case sortOrder = "sort_order"
    }
}

/** Task row */
struct TaskDto: Codable {
    var id: String
    var title: String
    var description: String?
    var categoryId: String?
    var estimateSeconds: Int64?
    var focusedSeconds: Int64
    var dueDate: Int64?
    var priority: String
    var status: String
    var createdAt: Int64
    var completedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, status
        case categoryId = "category_id"
        case estimateSeconds = "estimate_seconds"
        case focusedSeconds = "focused_seconds"
        case dueDate = "due_date"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    init(id: String, title: String, description: String?, categoryId: String?, estimateSeconds: Int64?, focusedSeconds: Int64, dueDate: Int64?, priority: String, status: String, createdAt: Int64, completedAt: Int64?) {
        self.id = id
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.estimateSeconds = estimateSeconds
        self.focusedSeconds = focusedSeconds
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        estimateSeconds = try container.decodeIfPresent(Int64.self, forKey: .estimateSeconds)
        focusedSeconds = try container.decodeIfPresent(Int64.self, forKey: .focusedSeconds) ?? 0
        dueDate = try container.decodeIfPresent(Int64.self, forKey: .dueDate)
        priority = try container.decode(String.self, forKey: .priority)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Int64.self, forKey: .completedAt)
    }
}

/** Habit row */
struct HabitDto: Codable {
    var id: String
    var name: String
    var icon: String
    var color: String
    var scheduleType: String
    var scheduleDaysMask: Int
    var targetPerDay: Int
    var reminderMinuteOfDay: Int?
    var note: String?
    var createdAt: Int64
    var archived: Bool
    var sortOrder: Int

    static let scheduleDaily = "daily"
    static let scheduleSelectedDays = "selected_days"
    /** Mask with all seven days set. */
    static let allDaysMask = 0b111_1111

    enum CodingKeys: String, CodingKey {
        case id, name, icon, color, note, archived
        case scheduleType = "schedule_type"
        case scheduleDaysMask = "schedule_days_mask"
        case targetPerDay = "target_per_day"
        case reminderMinuteOfDay = "reminder_minute_of_day"
        case createdAt = "created_at"
        case sortOrder = "sort_order"
    }

    init(id: String, name: String, icon: String, color: String, scheduleType: String, scheduleDaysMask: Int, targetPerDay: Int, reminderMinuteOfDay: Int?, note: String?, createdAt: Int64, archived: Bool, sortOrder: Int) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.scheduleType = scheduleType
        self.scheduleDaysMask = scheduleDaysMask
        self.targetPerDay = targetPerDay
        self.reminderMinuteOfDay = reminderMinuteOfDay
        self.note = note
        self.createdAt = createdAt
        self.archived = archived
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        scheduleType = try container.decode(String.self, forKey: .scheduleType)
        scheduleDaysMask = try container.decode(Int.self, forKey: .scheduleDaysMask)
        targetPerDay = try container.decode(Int.self, forKey: .targetPerDay)
        reminderMinuteOfDay = try container.decodeIfPresent(Int.self, forKey: .reminderMinuteOfDay)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decode(Int64.self, forKey: .createdAt)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

/** Habit completion */
struct HabitCompletionDto: Codable {
    var id: String
    var habitId: String
    var date: Int64
    var completedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, date
        case habitId = "habit_id"
        case completedAt = "completed_at"
    }
}

/**
 * Completed focus session. `category_id` is copied so past stats dont change if the task
 * category does
 */
struct FocusSessionDto: Codable {
    var id: String
    var taskId: String?
    var categoryId: String?
    var kind: String
    var plannedSeconds: Int64
    var actualSeconds: Int64
    var startedAt: Int64
    var endedAt: Int64
    var completed: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, completed
        case taskId = "task_id"
        case categoryId = "category_id"
        case plannedSeconds = "planned_seconds"
        case actualSeconds = "actual_seconds"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

// MARK: - Mappers

extension Date {
    var epochMillis: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(epochMillis: Int64) { self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1000) }
}

extension Category {
    var dto: CategoryDto { CategoryDto(id: id, name: name, color: color.rawValue, icon: icon, sortOrder: sortOrder) }
}

extension CategoryDto {
    var domain: Category { Category(id: id, name: name, color: .parse(color), icon: icon, sortOrder: sortOrder) }
}

extension FlowTask {
    var dto: TaskDto {
        TaskDto(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            estimateSeconds: estimateSeconds.map(Int64.init),
            focusedSeconds: Int64(focusedSeconds),
            dueDate: dueDate.map { Int64($0.epochDay) },
            priority: priority.rawValue,
            status: status.rawValue,
            createdAt: createdAt.epochMillis,
            completedAt: completedAt?.epochMillis
        )
    }
}

extension TaskDto {
    var domain: FlowTask {
        FlowTask(
            id: id,
            title: title,
            description: description,
            categoryId: categoryId,
            estimateSeconds: estimateSeconds.map { Int($0) },
            focusedSeconds: Int(focusedSeconds),
            dueDate: dueDate.map { LocalDate(epochDay: Int($0)) },
            priority: .parse(priority),
            status: .parse(status),
            createdAt: Date(epochMillis: createdAt),
            completedAt: completedAt.map(Date.init(epochMillis:))
        )
    }
}

extension Habit {
    var dto: HabitDto {
        let (type, mask): (String, Int) = switch schedule {
        case .daily: (HabitDto.scheduleDaily, HabitDto.allDaysMask)
        case .selectedDays(let days): (HabitDto.scheduleSelectedDays, days.mask)
        }
        return HabitDto(
            id: id,
            name: name,
            icon: icon,
            color: color.rawValue,
            scheduleType: type,
            scheduleDaysMask: mask,
            targetPerDay: max(targetPerDay, 1),
            reminderMinuteOfDay: reminderMinuteOfDay,
            note: note,
            createdAt: createdAt.epochMillis,
            archived: archived,
            sortOrder: sortOrder
        )
    }
}

extension HabitDto {
    var domain: Habit {
        Habit(
            id: id,
            name: name,
            icon: icon,
            color: .parse(color),
            schedule: scheduleType == HabitDto.scheduleSelectedDays ? .selectedDays(Set(daysFromMask: scheduleDaysMask)) : .daily,
            targetPerDay: max(targetPerDay, 1),
            reminderMinuteOfDay: reminderMinuteOfDay,
            note: note,
            createdAt: Date(epochMillis: createdAt),
            archived: archived,
            sortOrder: sortOrder
        )
    }
}

extension Set where Element == DayOfWeek {
    /** Monday = lowest bit. */
    var mask: Int { reduce(0) { $0 | (1 << $1.ordinal) } }

    init(daysFromMask mask: Int) {
        self = Set(DayOfWeek.allCases.filter { mask & (1 << $0.ordinal) != 0 })
    }
}

extension HabitCompletion {
    var dto: HabitCompletionDto {
        HabitCompletionDto(id: id, habitId: habitId, date: Int64(date.epochDay), completedAt: completedAt.epochMillis)
    }
}

extension HabitCompletionDto {
    var domain: HabitCompletion {
        HabitCompletion(id: id, habitId: habitId, date: LocalDate(epochDay: Int(date)), completedAt: Date(epochMillis: completedAt))
    }
}

extension FocusSession {
    var dto: FocusSessionDto {
        FocusSessionDto(
            id: id,
            taskId: taskId,
            categoryId: categoryId,
            kind: kind.rawValue,
            plannedSeconds: Int64(plannedSeconds),
            actualSeconds: Int64(actualSeconds),
            startedAt: startedAt.epochMillis,
            endedAt: endedAt.epochMillis,
            completed: completed
        )
    }
}

extension FocusSessionDto {
    var domain: FocusSession {
        FocusSession(
            id: id,
            taskId: taskId,
            categoryId: categoryId,
            kind: .parse(kind),
            plannedSeconds: Int(plannedSeconds),
            actualSeconds: Int(actualSeconds),
            startedAt: Date(epochMillis: startedAt),
            endedAt: Date(epochMillis: endedAt),
            completed: completed
        )
    }
}

extension AppSettings {
    var dto: SettingsDto {
        SettingsDto(
            themeMode: themeMode.rawValue,
            accentColor: accentColor.rawValue,
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            startOfWeek: startOfWeek.ordinal,
            notificationsEnabled: notificationsEnabled
        )
    }
}

extension SettingsDto {
    var domain: AppSettings {
        AppSettings(
            themeMode: .parse(themeMode),
            accentColor: .parse(accentColor),
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            startOfWeek: DayOfWeek(rawValue: startOfWeek) ?? .monday,
            notificationsEnabled: notificationsEnabled
        )
    }
}
