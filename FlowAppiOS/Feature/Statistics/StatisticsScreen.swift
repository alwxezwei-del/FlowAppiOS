import SwiftUI
import Observation

/**
 * Breakdown row with a progress bar
 */
struct DistributionRowUi: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let share: Double
    let color: AccentColor
    var icon: String? = nil
}

/**
 * Statistics screen state.
 */
struct StatisticsUiState {
    var period: StatisticsPeriod = .default
    var totalFocus = ""
    /** change vs previous period, nil if nothing to compare */
    var focusTrend: Double?
    /** the period has any data */
    var hasData = false
    var bars: [FlowBar] = []
    var completionRate: Double = 0
    var completedTasks = 0
    var totalTasks = 0
    var categories: [DistributionRowUi] = []
    var habits: [DistributionRowUi] = []
}

extension StatisticsPeriod {
    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

@MainActor
@Observable
final class StatisticsViewModel {
    private(set) var period: StatisticsPeriod = .default

    @ObservationIgnored private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func selectPeriod(_ period: StatisticsPeriod) {
        self.period = period
    }

    var state: StatisticsUiState {
        let timeProvider = container.timeProvider
        let summary = container.database.statistics(
            period: period,
            startOfWeek: container.settingsStore.settings.startOfWeek,
            timeProvider: timeProvider
        )
        return StatisticsUiState(
            period: period,
            totalFocus: summary.totalFocusSeconds.formatShort(),
            focusTrend: summary.focusTrend,
            hasData: summary.totalFocusSeconds > 0 || summary.totalTasks > 0 || !summary.habits.isEmpty,
            bars: bars(summary.dailyFocus, period: period, today: timeProvider.today()),
            completionRate: summary.completionRate,
            completedTasks: summary.completedTasks,
            totalTasks: summary.totalTasks,
            categories: summary.categories.map {
                DistributionRowUi(id: $0.categoryId ?? "none", title: $0.categoryName, value: $0.seconds.formatShort(), share: $0.share, color: $0.color)
            },
            habits: summary.habits.map {
                DistributionRowUi(id: $0.habitId, title: $0.habitName, value: "\($0.completedDays)/\($0.scheduledDays)", share: $0.rate, color: $0.color, icon: $0.icon)
            }
        )
    }

    /**
     * Year is grouped by month (365 bars are unreadable). Month labels every fifth day to avoid
     * overlap.
     */
    private func bars(_ daily: [DailyFocus], period: StatisticsPeriod, today: LocalDate) -> [FlowBar] {
        switch period {
        case .year:
            let byMonth = Dictionary(grouping: daily, by: \.date.month)
            return byMonth.keys.sorted().map { month in
                let total = byMonth[month]!.reduce(0) { $0 + $1.seconds }
                return FlowBar(
                    label: String(monthName(month).prefix(1)),
                    // Fractional minutes, otherwise short sessions vanish from the chart
                    value: Double(total) / 60,
                    description: "\(monthName(month)), \(total.formatShort())",
                    highlighted: month == today.month
                )
            }
        case .week, .month:
            let labelStep = daily.count <= 7 ? 1 : 5
            return daily.enumerated().map { index, day in
                FlowBar(
                    label: index % labelStep == 0 ? day.date.dayInitial() : "",
                    value: Double(day.seconds) / 60,
                    description: "\(day.date.formatShortDate()), \(day.seconds.formatShort())",
                    highlighted: day.date == today
                )
            }
        }
    }
}

/** Statistics */
struct StatisticsScreen: View {
    @State private var viewModel: StatisticsViewModel

    @Environment(\.flowColors) private var colors

    init(container: AppContainer) {
        _viewModel = State(initialValue: StatisticsViewModel(container: container))
    }

    var body: some View {
        let state = viewModel.state
        FlowScaffold(topBar: { FlowTopBar(title: "Statistics") }) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FlowSpacers.x16) {
                    FlowSegmentedControl(
                        items: StatisticsPeriod.allCases.map(\.label),
                        selectedIndex: StatisticsPeriod.allCases.firstIndex(of: state.period) ?? 0,
                        onSelect: { viewModel.selectPeriod(StatisticsPeriod.allCases[$0]) }
                    )

                    if !state.hasData {
                        FlowCard {
                            EmptyState(title: "Nothing to show yet", subtitle: "Run a focus session or complete a task — the numbers appear here.")
                        }
                    } else {
                        FlowCard {
                            Text("Focused").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
                            HStack(alignment: .lastTextBaseline, spacing: FlowSpacers.x8) {
                                Text(state.totalFocus).font(FlowTypography.display).foregroundStyle(colors.textMain)
                                if let trend = state.focusTrend {
                                    Text(trend.formatSignedPercent())
                                        .font(FlowTypography.caption)
                                        .foregroundStyle(trend >= 0 ? colors.success : colors.error)
                                }
                            }
                            FlowBarChart(bars: state.bars)
                        }

                        FlowCard {
                            Text("Completion rate").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
                            Text(state.completionRate.formatPercent()).font(FlowTypography.display).foregroundStyle(colors.textMain)
                            Text("\(state.completedTasks) of \(state.totalTasks) tasks completed")
                                .font(FlowTypography.caption)
                                .foregroundStyle(colors.textSecondary)
                            FlowProgressBar(progress: state.completionRate)
                        }

                        distribution(title: "Focus areas", rows: state.categories)
                        distribution(title: "Habit consistency", rows: state.habits)
                    }
                }
                .flowListPadding()
            }
        }
    }

    @ViewBuilder
    private func distribution(title: String, rows: [DistributionRowUi]) -> some View {
        if !rows.isEmpty {
            SectionHeader(title: title)
            FlowCard {
                VStack(spacing: FlowSpacers.x12) {
                    ForEach(rows) { DistributionRow(row: $0) }
                }
            }
        }
    }
}

private struct DistributionRow: View {
    let row: DistributionRowUi

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: FlowSpacers.x12) {
            if let icon = row.icon {
                FlowIconBadge(iconKey: icon, accent: row.color, size: FlowSpacers.x32)
            }
            VStack(spacing: FlowSpacers.x6) {
                HStack {
                    Text(row.title).font(FlowTypography.body2).foregroundStyle(colors.textMain)
                    Spacer()
                    Text(row.value).font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
                }
                FlowProgressBar(progress: row.share, color: colors.accent(row.color))
            }
        }
    }
}
