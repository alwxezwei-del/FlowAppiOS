import SwiftUI

struct StatsView: View {
    @Environment(StatsService.self) private var statsService
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    @State private var period = StatsPeriod.week

    var body: some View {
        let summary = statsService.summary(for: period)

        Screen(title: "Statistics") {
            ScrollContent(spacing: 16) {
                SegmentedPicker(options: StatsPeriod.allCases, selection: $period, title: \.title)

                if !summary.hasData {
                    FlowCard { EmptyState(title: "Nothing to show yet", subtitle: "Run a focus session or complete a task — the numbers appear here.") }
                } else {
                    FlowCard {
                        Text("Focused").font(.flowBody2).foregroundStyle(colors.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(summary.focusSeconds.durationText).font(.flowDisplay).foregroundStyle(colors.textMain)
                            if let trend = summary.focusTrend {
                                Text(trend.signedPercentText).font(.flowCaption).foregroundStyle(trend >= 0 ? colors.success : colors.error)
                            }
                        }
                        BarChart(bars: bars(summary.dailyFocus))
                    }

                    FlowCard {
                        Text("Completion rate").font(.flowBody2).foregroundStyle(colors.textSecondary)
                        Text(summary.completionRate.percentText).font(.flowDisplay).foregroundStyle(colors.textMain)
                        Text("\(summary.completedTasks) of \(summary.totalTasks) tasks completed").font(.flowCaption).foregroundStyle(colors.textSecondary)
                        ProgressBar(value: summary.completionRate)
                    }

                    if !summary.categories.isEmpty {
                        SectionHeader(title: "Focus areas")
                        FlowCard {
                            VStack(spacing: 12) {
                                ForEach(summary.categories, id: \.categoryId) { item in
                                    shareRow(item.name, value: item.seconds.durationText, share: item.share, color: item.color)
                                }
                            }
                        }
                    }

                    if !summary.habits.isEmpty {
                        SectionHeader(title: "Habit consistency")
                        FlowCard {
                            VStack(spacing: 12) {
                                ForEach(summary.habits, id: \.habit.id) { item in
                                    shareRow(item.habit.name, value: "\(item.completedDays)/\(item.scheduledDays)", share: item.rate, color: item.habit.color, icon: item.habit.icon)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func shareRow(_ title: String, value: String, share: Double, color: AccentColor, icon: String? = nil) -> some View {
        HStack(spacing: 12) {
            if let icon {
                IconBadge(icon: icon, accent: color, size: 32)
            }
            VStack(spacing: 6) {
                HStack {
                    Text(title).font(.flowBody2).foregroundStyle(colors.textMain)
                    Spacer()
                    Text(value).font(.flowBody2).foregroundStyle(colors.textSecondary)
                }
                ProgressBar(value: share, color: colors.accent(color))
            }
        }
    }

    /// A bar per day for week and month, a bar per month for the year.
    private func bars(_ days: [DailyFocus]) -> [Bar] {
        let today = time.today
        switch period {
        case .year:
            let byMonth = Dictionary(grouping: days, by: \.date.month)
            return byMonth.keys.sorted().map { month in
                let seconds = byMonth[month]!.reduce(0) { $0 + $1.seconds }
                return Bar(
                    label: String(monthNames[month - 1].prefix(1)),
                    value: Double(seconds),
                    accessibilityText: "\(monthNames[month - 1]), \(seconds.durationText)",
                    isHighlighted: month == today.month
                )
            }
        case .week, .month:
            // Label every fifth day of a month so the labels don't overlap
            let step = days.count > 7 ? 5 : 1
            return days.enumerated().map { index, day in
                Bar(
                    label: index % step == 0 ? day.date.initial : "",
                    value: Double(day.seconds),
                    accessibilityText: "\(day.date.shortText), \(day.seconds.durationText)",
                    isHighlighted: day.date == today
                )
            }
        }
    }
}

private extension StatsPeriod {
    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}
