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

    init(seedSamples: Bool) {
        storageURL = URL.documentsDirectory.appending(path: "flowapp-ios-state.json")
        load(seedSamples: seedSamples)
        didLoad = true
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

    func resetSampleData() {
        seed()
    }

    private func load(seedSamples: Bool) {
        guard let data = try? Data(contentsOf: storageURL), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            if seedSamples { seed() }
            return
        }
        tasks = snapshot.tasks
        habits = snapshot.habits
        categories = snapshot.categories
        sessions = snapshot.sessions
        settings = snapshot.settings
    }

    private func persist() {
        guard didLoad else { return }
        let snapshot = Snapshot(tasks: tasks, habits: habits, categories: categories, sessions: sessions, settings: settings)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func seed() {
        let work = FlowCategory(name: "Work", color: .purple, icon: "briefcase.fill")
        let learning = FlowCategory(name: "Learning", color: .blue, icon: "book.fill")
        let health = FlowCategory(name: "Health", color: .green, icon: "figure.run")
        categories = [work, learning, health]
        let now = Date()
        tasks = [
            FlowTask(title: "Design onboarding flow", notes: "Polish empty states and motion", categoryID: work.id, estimateMinutes: 60, focusedMinutes: 25, dueDate: now, priority: .high, status: .active, createdAt: now.addingDays(-2)),
            FlowTask(title: "Review pull requests", notes: "Check API layer changes", categoryID: work.id, estimateMinutes: 45, focusedMinutes: 0, dueDate: now, priority: .normal, status: .active, createdAt: now.addingDays(-1)),
            FlowTask(title: "Read Swift concurrency notes", notes: "Actors and cancellation", categoryID: learning.id, estimateMinutes: 30, focusedMinutes: 18, dueDate: now.addingDays(1), priority: .normal, status: .active, createdAt: now.addingDays(-3)),
            FlowTask(title: "Morning mobility", notes: "Light stretch", categoryID: health.id, estimateMinutes: 15, focusedMinutes: 15, dueDate: now, priority: .low, status: .completed, createdAt: now.addingDays(-1), completedAt: now)
        ]
        habits = [
            FlowHabit(name: "Code", icon: "chevron.left.forwardslash.chevron.right", color: .pink, targetPerDay: 1, note: "Daily practice", completedDates: [now.flowDayKey], createdAt: now.addingDays(-20)),
            FlowHabit(name: "Read", icon: "book.closed.fill", color: .blue, targetPerDay: 1, note: "At least 20 minutes", completedDates: [], createdAt: now.addingDays(-15)),
            FlowHabit(name: "Workout", icon: "figure.strengthtraining.traditional", color: .green, targetPerDay: 1, note: "Move every day", completedDates: [now.addingDays(-1).flowDayKey], createdAt: now.addingDays(-12))
        ]
        sessions = [
            FocusSession(taskID: tasks.first?.id, plannedMinutes: 25, actualMinutes: 25, startedAt: now.addingTimeInterval(-7200), endedAt: now.addingTimeInterval(-5700), completed: true),
            FocusSession(taskID: tasks.dropFirst().first?.id, plannedMinutes: 25, actualMinutes: 18, startedAt: now.addingDays(-1), endedAt: now.addingDays(-1).addingTimeInterval(1080), completed: false),
            FocusSession(taskID: tasks.first?.id, plannedMinutes: 45, actualMinutes: 40, startedAt: now.addingDays(-2), endedAt: now.addingDays(-2).addingTimeInterval(2400), completed: true)
        ]
        settings = AppSettings()
    }
}

private struct Snapshot: Codable {
    var tasks: [FlowTask]
    var habits: [FlowHabit]
    var categories: [FlowCategory]
    var sessions: [FocusSession]
    var settings: AppSettings
}
