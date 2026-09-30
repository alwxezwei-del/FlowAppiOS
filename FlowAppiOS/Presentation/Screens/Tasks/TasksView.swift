import SwiftUI

struct TasksView: View {
    enum Filter: CaseIterable {
        case all, today, upcoming, done

        var title: String {
            switch self {
            case .all: "All"
            case .today: "Today"
            case .upcoming: "Upcoming"
            case .done: "Done"
            }
        }
    }

    enum Sort: CaseIterable {
        case dueDate, priority, newest

        var title: String {
            switch self {
            case .dueDate: "By due date"
            case .priority: "By priority"
            case .newest: "Newest first"
            }
        }
    }

    @Environment(TaskService.self) private var taskService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    @State private var filter = Filter.all
    @State private var sort = Sort.dueDate

    var body: some View {
        let tasks = visibleTasks

        Screen(title: "Tasks", actions: AnyView(sortMenu), onAdd: { router.push(.taskEditor(taskId: nil)) }, addLabel: "New task") {
            ScrollContent(bottomInset: 56) {
                SegmentedPicker(options: Filter.allCases, selection: $filter, title: \.title)

                if tasks.isEmpty {
                    FlowCard { EmptyState(title: "Nothing here yet", subtitle: "Tap + to add your first task.") }
                }

                ForEach(tasks) { task in
                    let category = taskService.category(id: task.categoryId)
                    FlowCard(padding: 12) {
                        TaskRow(
                            task: task,
                            category: category,
                            subtitle: [category?.name, task.dueDate?.shortText, task.focusText].dotted,
                            onToggle: { taskService.setCompleted(task.id, $0) },
                            onTap: { router.push(.taskEditor(taskId: task.id)) }
                        ) {
                            HStack(spacing: 0) {
                                if !task.isCompleted {
                                    IconButton(
                                        systemName: "play",
                                        label: "Start focus session",
                                        tint: task.priority == .high ? colors.primary : nil
                                    ) { router.startFocus(taskId: task.id) }
                                }
                                MoreMenu {
                                    Button("Move to tomorrow") { taskService.reschedule(task.id, to: time.today.plusDays(1)) }
                                    Button("Delete", role: .destructive) { taskService.delete(task.id) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(Sort.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 20))
                .foregroundStyle(colors.iconSecondary)
                .frame(width: 48, height: 48)
        }
        .accessibilityLabel("Sort tasks")
    }

    private var visibleTasks: [FlowTask] {
        let today = time.today
        let filtered = taskService.allTasks.filter { task in
            switch filter {
            case .all: true
            case .today: task.status == .active && task.dueDate == today
            case .upcoming: task.status == .active && (task.dueDate.map { $0 > today } ?? false)
            case .done: task.isCompleted
            }
        }
        // Completed tasks always go last
        return filtered.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            switch sort {
            case .dueDate:
                switch (a.dueDate, b.dueDate) {
                case let (x?, y?): return x < y
                case (_?, nil): return true
                default: return false
                }
            case .priority: return a.priority.weight > b.priority.weight
            case .newest: return a.createdAt > b.createdAt
            }
        }
    }
}
