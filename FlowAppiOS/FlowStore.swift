import Foundation
import Combine

@MainActor
final class FlowStore: ObservableObject {
    @Published var tasks: [FlowTask] = [] { didSet { persist() } }
    @Published var habits: [FlowHabit] = [] { didSet { persist() } }
    @Published var categories: [FlowCategory] = [] { didSet { persist() } }
    @Published var sessions: [FocusSession] = [] { didSet { persist() } }
    @Published var settings = AppSettings() { didSet { persist() } }
    @Published var selectedDate = Date()

    private let storageURL: URL
    private var didLoad = false
    private var shouldPersistAfterLoad = false

    init(seedSamples: Bool) {
        storageURL = URL.documentsDirectory.appending(path: "flowapp-ios-state.json")
        load(seedSamples: seedSamples)
        didLoad = true
        if shouldPersistAfterLoad { persist() }
    }

    var todayTasks: [FlowTask] {
        tasks.filter { task in
            task.status == .active && (task.dueDate == nil || Calendar.current.isDate(task.dueDate!, inSameDayAs: selectedDate))
        }
    }

    var completedTodayCount: Int {
        tasks.filter { task in task.completedAt.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } ?? false }.count
    }

    var focusTodayMinutes: Int {
        sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate) }.map(\.actualMinutes).reduce(0, +)
    }

    func category(for id: UUID?) -> FlowCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func accent(for task: FlowTask) -> AccentColor {
        category(for: task.categoryID)?.color ?? .purple
    }

    func toggleTask(_ task: FlowTask, completed: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = completed ? .completed : .active
        tasks[index].completedAt = completed ? Date() : nil
    }

    func saveTask(_ task: FlowTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.insert(task, at: 0)
        }
    }

    func deleteTask(_ task: FlowTask) {
        tasks.removeAll { $0.id == task.id }
    }

    func toggleHabit(_ habit: FlowHabit, on date: Date, completed: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        if completed {
            habits[index].completedDates.insert(date.flowDayKey)
        } else {
            habits[index].completedDates.remove(date.flowDayKey)
        }
    }

    func saveFocusSession(taskID: UUID?, planned: Int, actual: Int, completed: Bool) {
        let end = Date()
        sessions.insert(FocusSession(taskID: taskID, plannedMinutes: planned, actualMinutes: actual, startedAt: end.addingTimeInterval(TimeInterval(-actual * 60)), endedAt: end, completed: completed), at: 0)
        if let taskID, let index = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[index].focusedMinutes += actual
        }
    }

    func resetAllData() {
        tasks = []
        habits = []
        sessions = []
        categories = defaultCategories
        settings = AppSettings()
    }

    private var defaultCategories: [FlowCategory] {
        [
            FlowCategory(name: "Work", color: .purple, icon: "briefcase.fill"),
            FlowCategory(name: "Learning", color: .blue, icon: "book.fill"),
            FlowCategory(name: "Health", color: .green, icon: "figure.run")
        ]
    }

    private func load(seedSamples: Bool) {
        guard let data = try? Data(contentsOf: storageURL), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            categories = defaultCategories
            return
        }

        if isLegacyBundledDemo(snapshot) {
            tasks = []
            habits = []
            sessions = []
            categories = defaultCategories
            settings = AppSettings()
            shouldPersistAfterLoad = true
            return
        }

        tasks = snapshot.tasks
        habits = snapshot.habits
        categories = snapshot.categories.isEmpty ? defaultCategories : snapshot.categories
        sessions = snapshot.sessions
        settings = snapshot.settings
    }

    private func persist() {
        guard didLoad else { return }
        let snapshot = Snapshot(tasks: tasks, habits: habits, categories: categories, sessions: sessions, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func isLegacyBundledDemo(_ snapshot: Snapshot) -> Bool {
        let demoTaskTitles = Set([
            "Design onboarding flow",
            "Review pull requests",
            "Read Swift concurrency notes",
            "Morning mobility"
        ])
        let demoHabitNames = Set(["Code", "Read", "Workout"])
        return Set(snapshot.tasks.map(\.title)) == demoTaskTitles && Set(snapshot.habits.map(\.name)) == demoHabitNames
    }

}

private struct Snapshot: Codable {
    var tasks: [FlowTask]
    var habits: [FlowHabit]
    var categories: [FlowCategory]
    var sessions: [FocusSession]
    var settings: AppSettings
}
