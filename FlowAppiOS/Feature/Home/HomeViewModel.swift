import Foundation
import Observation

/** Header greeting based on time of day */
enum Greeting {
    case morning, afternoon, evening

    var title: String {
        switch self {
        case .morning: "Good morning"
        case .afternoon: "Good afternoon"
        case .evening: "Good evening"
        }
    }
}

/** Day task item, ready to render */
struct HomeTaskUi: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let completed: Bool
    let accent: AccentColor
    var progress: Double = 0
}

/** Day habit item */
struct HomeHabitUi: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let accent: AccentColor
    let subtitle: String
    let completed: Bool
}

/**
 * Selected day data
 */
struct HomeUiState {
    let date: LocalDate
    let today: LocalDate
    let weekDays: [LocalDate]
    let greeting: Greeting
    let focusTotal: String
    let focusTrendPercent: Double?
    let tasks: [HomeTaskUi]
    let completedTasks: Int
    let totalTasks: Int
    let habits: [HomeHabitUi]

    /** Today is selected */
    var isToday: Bool { date == today }
}

/** Home screen actions */
enum HomeUiAction {
    case selectDate(LocalDate)
    case toggleTask(taskId: String, completed: Bool)
    case toggleHabit(habitId: String, completed: Bool)
}

@MainActor
@Observable
final class HomeViewModel {
    @ObservationIgnored private let container: AppContainer
    private var selectedDate: LocalDate

    init(container: AppContainer) {
        self.container = container
        selectedDate = container.timeProvider.today()
    }

    var state: HomeUiState {
        let timeProvider = container.timeProvider
        let date = selectedDate
        let snapshot = container.database.today(date)
        let streaks = container.database.habitStreaks(calculator: container.streakCalculator)
        let weekStart = date.startOfWeek(container.settingsStore.settings.startOfWeek)
        let categoriesById = Dictionary(uniqueKeysWithValues: snapshot.categories.map { ($0.id, $0) })

        return HomeUiState(
            date: date,
            today: timeProvider.today(),
            weekDays: (0..<7).map(weekStart.plusDays),
            greeting: currentGreeting(),
            focusTotal: snapshot.focusTodaySeconds.formatShort(),
            focusTrendPercent: snapshot.focusTrend,
            tasks: snapshot.tasks.map { task in
                let category = task.categoryId.flatMap { categoriesById[$0] }
                let parts = [category?.name, task.focusedSeconds.formatFocusProgress(estimate: task.estimateSeconds)].compactMap { $0 }
                return HomeTaskUi(
                    id: task.id,
                    title: task.title,
                    subtitle: parts.isEmpty ? nil : parts.joined(separator: Self.separator),
                    completed: task.isCompleted,
                    accent: category?.color ?? .default,
                    progress: task.focusProgress
                )
            },
            completedTasks: snapshot.completedTasks,
            totalTasks: snapshot.totalTasks,
            habits: snapshot.habits.map { progress in
                let streak = streaks[progress.habit.id].map(\.current).flatMap { $0 > 0 ? "\($0) day streak" : nil }
                return HomeHabitUi(
                    id: progress.habit.id,
                    name: progress.habit.name,
                    icon: progress.habit.icon,
                    accent: progress.habit.color,
                    subtitle: ["\(progress.completedCount)/\(progress.habit.targetPerDay)", streak].compactMap { $0 }.joined(separator: Self.separator),
                    completed: progress.isDone
                )
            }
        )
    }

    func onAction(_ action: HomeUiAction) {
        switch action {
        case .selectDate(let date):
            selectedDate = date
        case .toggleTask(let taskId, let completed):
            container.database.setStatus(taskId: taskId, status: completed ? .completed : .active)
        case .toggleHabit(let habitId, let completed):
            // Completion is recorded for the selected day, allowing backfilling past days.
            if completed {
                container.database.complete(habitId: habitId, date: selectedDate)
            } else {
                container.database.undoComplete(habitId: habitId, date: selectedDate)
            }
        }
    }

    private func currentGreeting() -> Greeting {
        let hour = container.timeProvider.hour(of: container.timeProvider.now())
        if hour < 12 { return .morning }
        if hour < 18 { return .afternoon }
        return .evening
    }

    private static let separator = " · "
}
