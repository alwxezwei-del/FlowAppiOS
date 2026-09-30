import SwiftUI

/** Home screen */
struct HomeScreen: View {
    private let router: AppRouter
    @State private var viewModel: HomeViewModel

    @Environment(\.flowColors) private var colors

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: HomeViewModel(container: container))
    }

    var body: some View {
        let state = viewModel.state
        FlowScaffold {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FlowSpacers.x16) {
                    HomeHeader(
                        greeting: state.greeting,
                        date: state.date,
                        onOpenHistory: { router.navigate(.history) },
                        onOpenSettings: { router.navigate(.settings) }
                    )

                    WeekStrip(days: state.weekDays, selected: state.date, today: state.today) {
                        viewModel.onAction(.selectDate($0))
                    }

                    FocusSummaryCard(
                        total: state.focusTotal,
                        trend: state.focusTrendPercent,
                        taskProgress: "\(state.completedTasks) / \(state.totalTasks) completed"
                    )

                    SectionHeader(
                        title: "Tasks",
                        trailing: state.totalTasks > 0 ? "\(state.completedTasks)/\(state.totalTasks)" : nil
                    )

                    if state.tasks.isEmpty {
                        FlowCard {
                            EmptyState(title: "No tasks for this day", subtitle: "Add one from the Tasks tab to plan your day.")
                        }
                    } else {
                        FlowCard(contentPadding: FlowSpacers.x12) {
                            ForEach(state.tasks) { task in
                                TaskRow(
                                    title: task.title,
                                    completed: task.completed,
                                    subtitle: task.subtitle,
                                    progress: task.progress,
                                    accent: task.accent,
                                    onClick: { router.navigate(.taskEditor(taskId: task.id)) },
                                    onToggle: { viewModel.onAction(.toggleTask(taskId: task.id, completed: $0)) }
                                )
                            }
                        }
                    }

                    SectionHeader(title: "Habits", trailing: "Manage") { router.navigate(.habits) }

                    if state.habits.isEmpty {
                        FlowCard {
                            EmptyState(title: "No habits scheduled", subtitle: "Create a habit to start building a streak.")
                        }
                    } else {
                        ForEach(state.habits) { habit in
                            FlowCard(contentPadding: FlowSpacers.x12) {
                                HabitRow(
                                    name: habit.name,
                                    iconKey: habit.icon,
                                    completed: habit.completed,
                                    accent: habit.accent,
                                    subtitle: habit.subtitle,
                                    onClick: { router.navigate(.habitDetails(habitId: habit.id)) },
                                    onToggle: { viewModel.onAction(.toggleHabit(habitId: habit.id, completed: $0)) }
                                )
                            }
                        }
                    }
                }
                .flowListPadding()
            }
        }
    }
}

private struct HomeHeader: View {
    let greeting: Greeting
    let date: LocalDate
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FlowSpacers.x2) {
                Text(greeting.title)
                    .font(FlowTypography.title1)
                    .foregroundStyle(colors.textMain)
                Text(date.formatFullDate())
                    .font(FlowTypography.body2)
                    .foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FlowIconButton(systemName: "clock.arrow.circlepath", accessibilityLabel: "Open history", tint: colors.iconSecondary, action: onOpenHistory)
            FlowIconButton(systemName: "gearshape", accessibilityLabel: "Open settings", tint: colors.iconSecondary, action: onOpenSettings)
        }
    }
}

/** Week strip in the header */
struct WeekStrip: View {
    let days: [LocalDate]
    let selected: LocalDate
    let today: LocalDate
    let onSelect: (LocalDate) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelected = day == selected
                Button { onSelect(day) } label: {
                    VStack(spacing: FlowSpacers.x6) {
                        Text(day.dayInitial())
                            .font(FlowTypography.caption)
                            .foregroundStyle(colors.textTertiary)
                        Text("\(day.day)")
                            .font(FlowTypography.body2)
                            .foregroundStyle(isSelected ? colors.textOnAccent : (day == today ? colors.primary : colors.textMain))
                            .frame(width: 32, height: 32)
                            .background(isSelected ? colors.primary : Color.clear, in: Circle())
                    }
                    .padding(FlowSpacers.x4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatFullDate())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if day != days.last { Spacer(minLength: 0) }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/** Today focus card */
private struct FocusSummaryCard: View {
    let total: String
    let trend: Double?
    let taskProgress: String

    @Environment(\.flowColors) private var colors

    var body: some View {
        FlowCard {
            Text("Today focus")
                .font(FlowTypography.body2)
                .foregroundStyle(colors.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: FlowSpacers.x8) {
                Text(total).font(FlowTypography.display).foregroundStyle(colors.textMain)
                if let trend {
                    let tint = trend >= 0 ? colors.success : colors.error
                    HStack(spacing: FlowSpacers.x2) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(trend.formatSignedPercent()).font(FlowTypography.caption)
                    }
                    .foregroundStyle(tint)
                }
            }
            Text(taskProgress)
                .font(FlowTypography.body2)
                .foregroundStyle(colors.textSecondary)
        }
    }
}
