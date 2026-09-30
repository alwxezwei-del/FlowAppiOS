import Foundation
import Observation

/** Task list filter */
enum TasksFilter: CaseIterable, Hashable {
    case all, today, upcoming, completed

    var label: String {
        switch self {
        case .all: "All"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .completed: "Done"
        }
    }
}

/** Sort order */
enum TasksSort: CaseIterable, Hashable {
    case dueDate, priority, created

    var label: String {
        switch self {
        case .dueDate: "By due date"
        case .priority: "By priority"
        case .created: "Newest first"
        }
    }
}

/**
 * Task list item
 */
struct TaskListItemUi: Identifiable, Hashable {
    let id: String
    let title: String
    /** Work Sep 30 45m */
    let subtitle: String?
    let completed: Bool
    let priority: Priority
    let accent: AccentColor
    /** enables "move to tomorrow" */
    let hasDueDate: Bool
    var progress: Double = 0
}

/** Tasks screen actions */
enum TasksUiAction {
    case selectFilter(TasksFilter)
    case selectSort(TasksSort)
    case toggleTask(taskId: String, completed: Bool)
    case moveToTomorrow(taskId: String)
    case deleteTask(taskId: String)
}

@MainActor
@Observable
final class TasksViewModel {
    @ObservationIgnored private let container: AppContainer
    private(set) var filter: TasksFilter = .all
    private(set) var sort: TasksSort = .dueDate

    init(container: AppContainer) {
        self.container = container
    }

    var tasks: [TaskListItemUi] {
        let database = container.database
        let today = container.timeProvider.today()
        return database.allTasks
            .filter { matches($0, filter: filter, today: today) }
            .sorted(by: comparator(sort))
            .map { task in
                let category = database.category(id: task.categoryId)
                let parts = [
                    category?.name,
                    task.dueDate?.formatShortDate(),
                    task.focusedSeconds.formatFocusProgress(estimate: task.estimateSeconds),
                ].compactMap { $0 }
                return TaskListItemUi(
                    id: task.id,
                    title: task.title,
                    subtitle: parts.isEmpty ? nil : parts.joined(separator: " · "),
                    completed: task.isCompleted,
                    priority: task.priority,
                    accent: category?.color ?? .default,
                    hasDueDate: task.dueDate != nil,
                    progress: task.focusProgress
                )
            }
    }

    func onAction(_ action: TasksUiAction) {
        let database = container.database
        switch action {
        case .selectFilter(let filter): self.filter = filter
        case .selectSort(let sort): self.sort = sort
        case .toggleTask(let taskId, let completed): database.setStatus(taskId: taskId, status: completed ? .completed : .active)
        case .moveToTomorrow(let taskId): database.reschedule(taskId: taskId, date: container.timeProvider.today().plusDays(1))
        case .deleteTask(let taskId): database.deleteTask(id: taskId)
        }
    }

    private func matches(_ task: FlowTask, filter: TasksFilter, today: LocalDate) -> Bool {
        switch filter {
        case .all: task.status != .archived
        case .today: task.status == .active && task.dueDate == today
        case .upcoming: task.status == .active && (task.dueDate.map { $0 > today } ?? false)
        case .completed: task.status == .completed
        }
    }

    /** Completed tasks always go last, then the selected order applies. */
    private func comparator(_ sort: TasksSort) -> (FlowTask, FlowTask) -> Bool {
        { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            switch sort {
            case .dueDate:
                // Tasks without a due date go last
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                default: return false
                }
            case .priority:
                return lhs.priority.weight > rhs.priority.weight
            case .created:
                return lhs.createdAt > rhs.createdAt
            }
        }
    }
}
