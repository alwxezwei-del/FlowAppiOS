import SwiftUI
import Observation

/**
 * Habit list item
 */
struct HabitListItemUi: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let accent: AccentColor
    /** №day streak */
    let subtitle: String
    let completed: Bool
    let scheduledToday: Bool
    let archived: Bool
}

/**
 * Habits screen state
 */
struct HabitsUiState {
    var todayHabits: [HabitListItemUi] = []
    /** active habits not scheduled today */
    var otherHabits: [HabitListItemUi] = []
    var archivedHabits: [HabitListItemUi] = []

    var isEmpty: Bool { todayHabits.isEmpty && otherHabits.isEmpty && archivedHabits.isEmpty }
}

/** Habits screen actions */
enum HabitsUiAction {
    case toggleHabit(habitId: String, completed: Bool)
    case setArchived(habitId: String, archived: Bool)
    case deleteHabit(habitId: String)
}

@MainActor
@Observable
final class HabitsViewModel {
    @ObservationIgnored private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var state: HabitsUiState {
        let database = container.database
        let today = container.timeProvider.today()
        let todayCompletions = Dictionary(grouping: database.completions.filter { $0.date == today }, by: \.habitId).mapValues(\.count)
        let streaks = database.habitStreaks(calculator: container.streakCalculator)

        let items = database.allHabits.map { habit in
            let done = todayCompletions[habit.id] ?? 0
            let streak = streaks[habit.id].map(\.current).flatMap { $0 > 0 ? "\($0) day streak" : nil }
            return HabitListItemUi(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                accent: habit.color,
                subtitle: ["\(done)/\(habit.targetPerDay)", streak].compactMap { $0 }.joined(separator: " · "),
                completed: done >= habit.targetPerDay,
                scheduledToday: habit.schedule.isScheduled(on: today),
                archived: habit.archived
            )
        }
        return HabitsUiState(
            todayHabits: items.filter { !$0.archived && $0.scheduledToday },
            otherHabits: items.filter { !$0.archived && !$0.scheduledToday },
            archivedHabits: items.filter(\.archived)
        )
    }

    func onAction(_ action: HabitsUiAction) {
        let database = container.database
        let today = container.timeProvider.today()
        switch action {
        case .toggleHabit(let habitId, let completed):
            if completed { database.complete(habitId: habitId, date: today) } else { database.undoComplete(habitId: habitId, date: today) }
        case .setArchived(let habitId, let archived):
            database.setArchived(habitId: habitId, archived: archived)
        case .deleteHabit(let habitId):
            database.deleteHabit(id: habitId)
        }
    }
}

/** Habits screen */
struct HabitsScreen: View {
    private let router: AppRouter
    @State private var viewModel: HabitsViewModel

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: HabitsViewModel(container: container))
    }

    var body: some View {
        let state = viewModel.state
        FlowScaffold(
            topBar: { FlowTopBar(title: "Habits", onBack: router.navigateUp) },
            fab: .init(accessibilityLabel: "New habit") { router.navigate(.habitEditor(habitId: nil)) }
        ) {
            ScrollView {
                LazyVStack(spacing: FlowSpacers.x12) {
                    if state.isEmpty {
                        FlowCard {
                            EmptyState(title: "No habits yet", subtitle: "Add a habit and start building a streak.")
                        }
                    }
                    section(title: "Today", habits: state.todayHabits)
                    section(title: "Other days", habits: state.otherHabits)
                    section(title: "Archived", habits: state.archivedHabits)
                }
                .flowListPadding()
                .padding(.bottom, 56)
            }
        }
    }

    @ViewBuilder
    private func section(title: String, habits: [HabitListItemUi]) -> some View {
        if !habits.isEmpty {
            SectionHeader(title: title)
            ForEach(habits) { habit in
                FlowCard(contentPadding: FlowSpacers.x12) {
                    HabitRow(
                        name: habit.name,
                        iconKey: habit.icon,
                        completed: habit.completed,
                        accent: habit.accent,
                        subtitle: habit.subtitle,
                        onClick: { router.navigate(.habitDetails(habitId: habit.id)) },
                        onToggle: { viewModel.onAction(.toggleHabit(habitId: habit.id, completed: $0)) }
                    ) {
                        FlowMoreMenu(accessibilityLabel: "More actions") {
                            Button(habit.archived ? "Restore" : "Archive", systemImage: habit.archived ? "archivebox.fill" : "archivebox") {
                                viewModel.onAction(.setArchived(habitId: habit.id, archived: !habit.archived))
                            }
                            Button("Delete", role: .destructive) {
                                viewModel.onAction(.deleteHabit(habitId: habit.id))
                            }
                        }
                    }
                }
            }
        }
    }
}
