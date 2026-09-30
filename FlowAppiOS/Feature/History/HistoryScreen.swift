import SwiftUI
import Observation

/**
 * Feed event
 */
struct HistoryEventUi: Identifiable, Hashable {
    let id: String
    let time: String
    let title: String
    let subtitle: String?
    let icon: String
    let accent: AccentColor
}

/**
 * Events of one day
 */
struct HistoryDayUi: Identifiable, Hashable {
    let title: String
    let events: [HistoryEventUi]

    var id: String { title }
}

extension HistoryFilter {
    var label: String {
        switch self {
        case .all: "All"
        case .focus: "Focus"
        case .tasks: "Tasks"
        case .habits: "Habits"
        }
    }
}

@MainActor
@Observable
final class HistoryViewModel {
    private(set) var filter: HistoryFilter = .default

    @ObservationIgnored private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func selectFilter(_ filter: HistoryFilter) {
        self.filter = filter
    }

    var days: [HistoryDayUi] {
        let timeProvider = container.timeProvider
        let today = timeProvider.today()
        let yesterday = today.minusDays(1)
        let range = DateRange(start: today.plusMonths(-Self.historyMonths), endInclusive: today)
        let events = container.database.history(range: range, filter: filter)

        let byDay = Dictionary(grouping: events) { timeProvider.localDate(of: $0.timestamp) }
        return byDay.keys.sorted(by: >).map { date in
            HistoryDayUi(
                title: date == today ? "Today" : (date == yesterday ? "Yesterday" : date.formatShortDate()),
                events: byDay[date]!.map(toUi)
            )
        }
    }

    private func toUi(_ event: HistoryEvent) -> HistoryEventUi {
        let calendar = container.timeProvider.calendar
        let components = calendar.dateComponents([.hour, .minute], from: event.timestamp)
        let time = formatTime(minuteOfDay: (components.hour ?? 0) * 60 + (components.minute ?? 0))

        switch event {
        case .focusFinished(let id, _, let taskTitle, let kind, let seconds, let completed):
            let kindLabel = switch kind {
            case .focus: "focus"
            case .shortBreak: "short break"
            case .longBreak: "long break"
            }
            let subtitle = [taskTitle, completed ? nil : "interrupted"].compactMap { $0 }.joined(separator: " · ")
            return HistoryEventUi(
                id: id,
                time: time,
                title: "\(seconds.formatShort()) \(kindLabel)",
                subtitle: subtitle.isEmpty ? nil : subtitle,
                icon: FlowIconKey.code,
                accent: .purple
            )
        case .taskCompleted(let id, _, let title, let categoryName, let color):
            return HistoryEventUi(id: id, time: time, title: title, subtitle: categoryName, icon: FlowIconKey.work, accent: color)
        case .habitCompleted(let id, _, let habitName, let icon, let color):
            return HistoryEventUi(id: id, time: time, title: habitName, subtitle: "Habit completed", icon: icon, accent: color)
        }
    }

    private static let historyMonths = 3
}

/** History feed */
struct HistoryScreen: View {
    private let router: AppRouter
    @State private var viewModel: HistoryViewModel

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: HistoryViewModel(container: container))
    }

    var body: some View {
        let days = viewModel.days
        FlowScaffold(topBar: { FlowTopBar(title: "History", onBack: router.navigateUp) }) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FlowSpacers.x12) {
                    FlowSegmentedControl(
                        items: HistoryFilter.allCases.map(\.label),
                        selectedIndex: HistoryFilter.allCases.firstIndex(of: viewModel.filter) ?? 0,
                        onSelect: { viewModel.selectFilter(HistoryFilter.allCases[$0]) }
                    )

                    if days.isEmpty {
                        FlowCard {
                            EmptyState(title: "No activity yet", subtitle: "Completed tasks, habits and focus sessions show up here.")
                        }
                    }

                    ForEach(days) { day in
                        SectionHeader(title: day.title)
                        FlowCard {
                            VStack(spacing: FlowSpacers.x12) {
                                ForEach(day.events) { HistoryRow(event: $0) }
                            }
                        }
                    }
                }
                .flowListPadding()
            }
        }
    }
}

private struct HistoryRow: View {
    let event: HistoryEventUi

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: FlowSpacers.x12) {
            Text(event.time)
                .font(FlowTypography.caption)
                .foregroundStyle(colors.textTertiary)
                .frame(width: 52, alignment: .leading)
            FlowIconBadge(iconKey: event.icon, accent: event.accent, size: FlowSpacers.x32)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(FlowTypography.body2).foregroundStyle(colors.textMain)
                if let subtitle = event.subtitle {
                    Text(subtitle).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
