import Foundation
import Observation

/** App database */
@MainActor
@Observable
final class FlowDatabase {
    private(set) var categories: [Category] = []
    private(set) var tasks: [FlowTask] = []
    private(set) var habits: [Habit] = []
    /** All completions of all habits, used for streaks */
    private(set) var completions: [HabitCompletion] = []
    private(set) var sessions: [FocusSession] = []

    @ObservationIgnored private let fileURL: URL?
    @ObservationIgnored private let timeProvider: TimeProvider

    init(fileURL: URL? = FlowDatabase.defaultFileURL, timeProvider: TimeProvider) {
        self.fileURL = fileURL
        self.timeProvider = timeProvider
        load()
    }

    nonisolated static var defaultFileURL: URL {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "flowapp.json")
    }

    // MARK: - User defined categories

    var sortedCategories: [Category] {
        categories.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    func category(id: String?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func createCategory(_ category: Category) {
        categories.append(category)
        save()
    }

    func deleteCategory(id: String) {
        categories.removeAll { $0.id == id }
        for index in tasks.indices where tasks[index].categoryId == id {
            tasks[index].categoryId = nil
        }
        save()
    }

    // MARK: - Tasks

    /** All tasks */
    var allTasks: [FlowTask] {
        tasks
            .filter { $0.status != .archived }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?) where l != r: return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.createdAt > rhs.createdAt
                }
            }
    }

    func tasks(for date: LocalDate) -> [FlowTask] {
        tasks
            .filter { $0.dueDate == date && $0.status != .archived }
            .sorted { ($0.status.rawValue, $0.createdAt) < ($1.status.rawValue, $1.createdAt) }
    }

    /** Tasks with a due date within the range */
    func tasks(in range: DateRange) -> [FlowTask] {
        tasks
            .filter { $0.dueDate.map(range.contains) ?? false }
            .sorted { ($0.dueDate!, $0.createdAt) < ($1.dueDate!, $1.createdAt) }
    }

    func task(id: String?) -> FlowTask? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    func createTask(_ task: FlowTask) {
        tasks.append(task)
        save()
    }

    func updateTask(_ task: FlowTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        save()
    }

    /** Sets task status */
    func setStatus(taskId: String, status: TaskStatus) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].status = status
        tasks[index].completedAt = status == .completed ? timeProvider.now() : nil
        save()
    }

    /** Moves the task to another day */
    func reschedule(taskId: String, date: LocalDate?) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].dueDate = date
        save()
    }

    /** Adds a completed focus session's duration to the task */
    func addFocusedTime(taskId: String, seconds: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[index].focusedSeconds += seconds
        save()
    }

    func deleteTask(id: String) {
        tasks.removeAll { $0.id == id }
        for index in sessions.indices where sessions[index].taskId == id {
            sessions[index].taskId = nil
        }
        save()
    }

    // MARK: - Habits and their completion history

    private static func habitOrder(_ lhs: Habit, _ rhs: Habit) -> Bool {
        (lhs.sortOrder, lhs.name) < (rhs.sortOrder, rhs.name)
    }

    /** Active habits */
    var activeHabits: [Habit] {
        habits.filter { !$0.archived }.sorted(by: Self.habitOrder)
    }

    /** All habits, including archived */
    var allHabits: [Habit] {
        habits.sorted { lhs, rhs in
            lhs.archived != rhs.archived ? !lhs.archived : Self.habitOrder(lhs, rhs)
        }
    }

    func habit(id: String?) -> Habit? {
        guard let id else { return nil }
        return habits.first { $0.id == id }
    }

    /** Habits scheduled for the day, with that day progress */
    func habitProgress(for date: LocalDate) -> [HabitDayProgress] {
        let countByHabit = Dictionary(grouping: completions.filter { $0.date == date }, by: \.habitId).mapValues(\.count)
        return activeHabits
            .filter { $0.schedule.isScheduled(on: date) }
            .map { HabitDayProgress(habit: $0, date: date, completedCount: countByHabit[$0.id] ?? 0, scheduled: true) }
    }

    /** Completions in range */
    func completions(in range: DateRange) -> [HabitCompletion] {
        completions.filter { range.contains($0.date) }.sorted { $0.completedAt > $1.completedAt }
    }

    /** All completions of one habit */
    func completions(habitId: String) -> [HabitCompletion] {
        completions.filter { $0.habitId == habitId }.sorted { $0.date < $1.date }
    }

    func createHabit(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func updateHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
        save()
    }

    /** Adds a completion for the given day */
    func complete(habitId: String, date: LocalDate) {
        completions.append(HabitCompletion(habitId: habitId, date: date, completedAt: timeProvider.now()))
        save()
    }

    /** Removes the latest completion for the day */
    func undoComplete(habitId: String, date: LocalDate) {
        let latest = completions
            .filter { $0.habitId == habitId && $0.date == date }
            .max { $0.completedAt < $1.completedAt }
        guard let latest else { return }
        completions.removeAll { $0.id == latest.id }
        save()
    }

    /** Archives or unarchives a habit */
    func setArchived(habitId: String, archived: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }
        habits[index].archived = archived
        save()
    }

    func deleteHabit(id: String) {
        habits.removeAll { $0.id == id }
        completions.removeAll { $0.habitId == id }
        save()
    }

    // MARK: - Completed focus sessions

    /** Sessions in range, newest first */
    func sessions(in range: DateRange) -> [FocusSession] {
        let bounds = range.instants(in: timeProvider.calendar)
        return sessions.filter { bounds.contains($0.endedAt) }.sorted { $0.endedAt > $1.endedAt }
    }

    /** Total focused time in range */
    func totalFocusSeconds(in range: DateRange) -> Int {
        sessions(in: range).filter { $0.kind == .focus }.reduce(0) { $0 + $1.actualSeconds }
    }

    func saveSession(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        save()
    }

    // MARK: - Bulk

    /** Full dump for JSON export. */
    var snapshot: DatabaseDto {
        DatabaseDto(
            categories: categories.map(\.dto),
            tasks: tasks.map(\.dto),
            habits: habits.map(\.dto),
            habitCompletions: completions.map(\.dto),
            focusSessions: sessions.map(\.dto)
        )
    }

    func replaceAll(with content: DatabaseDto) {
        // Order matters: foreign keys require parents before children
        categories = content.categories.map(\.domain)
        let categoryIds = Set(categories.map(\.id))
        tasks = content.tasks.map(\.domain).map { task in
            var task = task
            if let id = task.categoryId, !categoryIds.contains(id) { task.categoryId = nil }
            return task
        }
        habits = content.habits.map(\.domain)
        let habitIds = Set(habits.map(\.id))
        completions = content.habitCompletions.map(\.domain).filter { habitIds.contains($0.habitId) }
        let taskIds = Set(tasks.map(\.id))
        sessions = content.focusSessions.map(\.domain).map { session in
            var session = session
            if let id = session.taskId, !taskIds.contains(id) { session.taskId = nil }
            return session
        }
        save()
    }

    func clear() {
        replaceAll(with: DatabaseDto())
    }

    // MARK: - Persistence

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let content = try? JSONDecoder().decode(DatabaseDto.self, from: data) else { return }
        categories = content.categories.map(\.domain)
        tasks = content.tasks.map(\.domain)
        habits = content.habits.map(\.domain)
        completions = content.habitCompletions.map(\.domain)
        sessions = content.focusSessions.map(\.domain)
    }

    private func save() {
        guard let fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
