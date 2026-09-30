import Foundation
import Observation

/// Tasks and their categories.
@MainActor
@Observable
final class TaskService {
    private(set) var tasks: [FlowTask] = []
    private(set) var categories: [Category] = []

    @ObservationIgnored private let file: JSONFile<Stored>
    @ObservationIgnored private let time: TimeSource

    private struct Stored: Codable {
        var categories: [Category]
        var tasks: [FlowTask]
    }

    init(time: TimeSource, fileName: String? = "tasks.json") {
        self.time = time
        file = JSONFile(fileName)
        if let stored = file.load() {
            tasks = stored.tasks
            categories = stored.categories
        }
    }

    // MARK: Queries

    var sortedCategories: [Category] {
        categories.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }

    func category(id: String?) -> Category? {
        categories.first { $0.id == id }
    }

    func task(id: String?) -> FlowTask? {
        tasks.first { $0.id == id }
    }

    /// Everything except archived, dated tasks first and newest first within a day.
    var allTasks: [FlowTask] {
        tasks.filter { $0.status != .archived }.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: x < y
            case (nil, _?): false
            case (_?, nil): true
            default: a.createdAt > b.createdAt
            }
        }
    }

    /// Active tasks first, then in creation order.
    func tasks(on date: LocalDate) -> [FlowTask] {
        tasks
            .filter { $0.dueDate == date && $0.status != .archived }
            .sorted { ($0.isCompleted ? 1 : 0, $0.createdAt) < ($1.isCompleted ? 1 : 0, $1.createdAt) }
    }

    func tasks(dueIn range: DateRange) -> [FlowTask] {
        tasks.filter { $0.dueDate.map(range.contains) ?? false }
    }

    // MARK: Changes

    func add(_ task: FlowTask) {
        tasks.append(task)
        save()
    }

    func update(_ task: FlowTask) {
        modify(task.id) { $0 = task }
    }

    func setCompleted(_ id: String, _ completed: Bool) {
        modify(id) {
            $0.status = completed ? .completed : .active
            $0.completedAt = completed ? time.now() : nil
        }
    }

    func reschedule(_ id: String, to date: LocalDate?) {
        modify(id) { $0.dueDate = date }
    }

    /// Logs focused time and closes the task once its estimate is reached.
    func addFocusedTime(_ id: String, seconds: Int) {
        modify(id) { task in
            task.focusedSeconds += seconds
            if task.status == .active && task.focusProgress >= 1 {
                task.status = .completed
                task.completedAt = time.now()
            }
        }
    }

    func delete(_ id: String) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func seedDefaultCategories() {
        guard categories.isEmpty else { return }
        categories = [
            Category(name: "Work", color: .purple, icon: "work", sortOrder: 0),
            Category(name: "Learning", color: .blue, icon: "learning", sortOrder: 1),
            Category(name: "Personal", color: .orange, icon: "personal", sortOrder: 2),
            Category(name: "Health", color: .green, icon: "health", sortOrder: 3),
        ]
        save()
    }

    func replaceAll(categories: [Category], tasks: [FlowTask]) {
        self.categories = categories
        self.tasks = tasks
        save()
    }

    private func modify(_ id: String, _ change: (inout FlowTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
        save()
    }

    private func save() {
        file.save(Stored(categories: categories, tasks: tasks))
    }
}
