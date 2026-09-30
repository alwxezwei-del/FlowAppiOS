import SwiftUI
import Observation

struct HabitDayUi: Hashable {
    let date: LocalDate
    let scheduled: Bool
    let completed: Bool
}

/**
 * Habit details state
 */
struct HabitDetailsUiState {
    var name = ""
    var icon = ""
    var accent: AccentColor = .default
    var scheduleLabel = ""
    var currentStreak = 0
    var longestStreak = 0
    var completionRate: Double = 0
    var days: [HabitDayUi] = []
}

@MainActor
@Observable
final class HabitDetailsViewModel {
    @ObservationIgnored private let container: AppContainer
    @ObservationIgnored private let habitId: String

    init(container: AppContainer, habitId: String) {
        self.container = container
        self.habitId = habitId
    }

    var state: HabitDetailsUiState {
        let database = container.database
        guard let habit = database.habit(id: habitId) else { return HabitDetailsUiState() }
        let completions = database.completions(habitId: habitId)
        let today = container.timeProvider.today()
        let calculator = container.streakCalculator
        let streaks = calculator.calculate(habit: habit, completions: completions, today: today)
        let doneDays = calculator.doneDays(of: habit, completions: completions)

        let firstDay = today.minusDays(Self.gridDays - 1)
        let days = (0..<Self.gridDays).map { offset in
            let date = firstDay.plusDays(offset)
            return HabitDayUi(date: date, scheduled: habit.schedule.isScheduled(on: date), completed: doneDays.contains(date))
        }

        return HabitDetailsUiState(
            name: habit.name,
            icon: habit.icon,
            accent: habit.color,
            scheduleLabel: habit.schedule.label,
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            completionRate: streaks.completionRate,
            days: days
        )
    }

    func toggleDay(_ date: LocalDate, completed: Bool) {
        if completed {
            container.database.complete(habitId: habitId, date: date)
        } else {
            container.database.undoComplete(habitId: habitId, date: date)
        }
    }

    private static let gridDays = 30
}

extension HabitSchedule {
    var label: String {
        switch self {
        case .daily: "Every day"
        case .selectedDays(let days): DayOfWeek.allCases.filter(days.contains).map(\.shortName).joined(separator: ", ")
        }
    }
}

/**
 * Habit details
 */
struct HabitDetailsScreen: View {
    private let router: AppRouter
    private let habitId: String
    @State private var viewModel: HabitDetailsViewModel

    @Environment(\.flowColors) private var colors

    init(container: AppContainer, habitId: String) {
        router = container.router
        self.habitId = habitId
        _viewModel = State(initialValue: HabitDetailsViewModel(container: container, habitId: habitId))
    }

    var body: some View {
        let state = viewModel.state
        FlowScaffold(topBar: { FlowTopBar(title: state.name, onBack: router.navigateUp) }) {
            ScrollView {
                VStack(spacing: FlowSpacers.x16) {
                    FlowCard {
                        HStack(spacing: FlowSpacers.x12) {
                            FlowIconBadge(iconKey: state.icon, accent: state.accent)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(state.name).font(FlowTypography.title2).foregroundStyle(colors.textMain)
                                Text(state.scheduleLabel).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: FlowSpacers.x12) {
                        StatTile(title: "Current streak", value: "\(state.currentStreak) days")
                        StatTile(title: "Longest streak", value: "\(state.longestStreak) days")
                        StatTile(title: "Completion rate", value: state.completionRate.formatPercent())
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    FlowCard {
                        Text("Last 30 days")
                            .font(FlowTypography.body2)
                            .foregroundStyle(colors.textSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: FlowSpacers.x6), count: 10), spacing: FlowSpacers.x6) {
                            ForEach(state.days, id: \.date) { day in
                                DayCell(day: day, accent: state.accent) {
                                    viewModel.toggleDay(day.date, completed: !day.completed)
                                }
                            }
                        }
                        .padding(.top, FlowSpacers.x12)
                    }

                    FlowSecondaryButton(text: "Edit") { router.navigate(.habitEditor(habitId: habitId)) }
                }
                .padding(.horizontal, FlowSpacers.x16)
                .padding(.bottom, FlowSpacers.x24)
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    @Environment(\.flowColors) private var colors

    var body: some View {
        FlowCard(contentPadding: FlowSpacers.x12) {
            Text(title).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
            Spacer(minLength: 0)
            Text(value).font(FlowTypography.title2).foregroundStyle(colors.textMain)
        }
        .frame(maxHeight: .infinity)
    }
}

private struct DayCell: View {
    let day: HabitDayUi
    let accent: AccentColor
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FlowRadius.x8, style: .continuous)
        Button(action: onClick) {
            shape
                .fill(day.completed ? colors.accent(accent) : (day.scheduled ? colors.layer2 : colors.layer1))
                .overlay(shape.strokeBorder(colors.divider, lineWidth: hairline))
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatFullDate())
        .accessibilityAddTraits(day.completed ? .isSelected : [])
    }
}
