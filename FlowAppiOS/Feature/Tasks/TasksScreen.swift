import SwiftUI

/** Task list with filters, sorting and creation */
struct TasksScreen: View {
    private let router: AppRouter
    @State private var viewModel: TasksViewModel

    @Environment(\.flowColors) private var colors

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: TasksViewModel(container: container))
    }

    var body: some View {
        let tasks = viewModel.tasks
        FlowScaffold(
            topBar: {
                FlowTopBar(title: "Tasks") {
                    Menu {
                        Picker("Sort tasks", selection: Binding(get: { viewModel.sort }, set: { viewModel.onAction(.selectSort($0)) })) {
                            ForEach(TasksSort.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 20))
                            .foregroundStyle(colors.iconSecondary)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Sort tasks")
                }
            },
            fab: .init(accessibilityLabel: "New task") { router.navigate(.taskEditor(taskId: nil)) }
        ) {
            ScrollView {
                LazyVStack(spacing: FlowSpacers.x12) {
                    FlowSegmentedControl(
                        items: TasksFilter.allCases.map(\.label),
                        selectedIndex: TasksFilter.allCases.firstIndex(of: viewModel.filter) ?? 0,
                        onSelect: { viewModel.onAction(.selectFilter(TasksFilter.allCases[$0])) }
                    )

                    if tasks.isEmpty {
                        FlowCard {
                            EmptyState(title: "Nothing here yet", subtitle: "Tap + to add your first task.")
                        }
                    }

                    ForEach(tasks) { task in
                        FlowCard(contentPadding: FlowSpacers.x12) {
                            TaskListRow(
                                task: task,
                                onToggle: { viewModel.onAction(.toggleTask(taskId: task.id, completed: $0)) },
                                onClick: { router.navigate(.taskEditor(taskId: task.id)) },
                                onStartFocus: { router.startFocus(taskId: task.id) },
                                onMoveToTomorrow: { viewModel.onAction(.moveToTomorrow(taskId: task.id)) },
                                onDelete: { viewModel.onAction(.deleteTask(taskId: task.id)) }
                            )
                        }
                    }
                }
                .flowListPadding()
                .padding(.bottom, 56)
            }
        }
    }
}

/** Task row with an overflow menu for "move to tomorrow" and delete. */
private struct TaskListRow: View {
    let task: TaskListItemUi
    let onToggle: (Bool) -> Void
    let onClick: () -> Void
    let onStartFocus: () -> Void
    let onMoveToTomorrow: () -> Void
    let onDelete: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        TaskRow(
            title: task.title,
            completed: task.completed,
            subtitle: task.subtitle,
            progress: task.progress,
            accent: task.accent,
            onClick: onClick,
            onToggle: onToggle
        ) {
            HStack(spacing: 0) {
                if !task.completed {
                    FlowIconButton(
                        systemName: "play",
                        accessibilityLabel: "Start focus session",
                        tint: task.priority == .high ? colors.primary : colors.iconSecondary,
                        action: onStartFocus
                    )
                }
                FlowMoreMenu(accessibilityLabel: "More actions") {
                    Button("Move to tomorrow", action: onMoveToTomorrow)
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
        }
    }
}
