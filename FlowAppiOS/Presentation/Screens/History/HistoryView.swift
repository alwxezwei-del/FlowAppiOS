import SwiftUI

struct HistoryView: View {
    @Environment(StatsService.self) private var statsService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time

    @State private var filter = HistoryFilter.all

    var body: some View {
        let byDay = Dictionary(grouping: statsService.history(filter: filter)) { time.day(of: $0.date) }

        Screen(title: "History", onBack: { router.pop() }) {
            ScrollContent {
                SegmentedPicker(options: HistoryFilter.allCases, selection: $filter, title: \.title)

                if byDay.isEmpty {
                    FlowCard { EmptyState(title: "No activity yet", subtitle: "Completed tasks, habits and focus sessions show up here.") }
                }

                ForEach(byDay.keys.sorted(by: >), id: \.self) { day in
                    SectionHeader(title: title(of: day))
                    FlowCard {
                        VStack(spacing: 12) {
                            ForEach(byDay[day]!) { EventRow(event: $0) }
                        }
                    }
                }
            }
        }
    }

    private func title(of day: LocalDate) -> String {
        switch day {
        case time.today: "Today"
        case time.today.minusDays(1): "Yesterday"
        default: day.shortText
        }
    }
}

private struct EventRow: View {
    let event: HistoryEvent

    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    var body: some View {
        let parts = time.calendar.dateComponents([.hour, .minute], from: event.date)
        HStack(spacing: 12) {
            Text(timeText(minuteOfDay: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)))
                .font(.flowCaption)
                .foregroundStyle(colors.textTertiary)
                .frame(width: 52, alignment: .leading)
            IconBadge(icon: icon, accent: accent, size: 32)
            VStack(alignment: .leading) {
                Text(title).font(.flowBody2).foregroundStyle(colors.textMain)
                if let subtitle {
                    Text(subtitle).font(.flowCaption).foregroundStyle(colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: String {
        switch event {
        case .taskCompleted(let task, _, _): task.title
        case .habitCompleted(let habit, _): habit.name
        case .focusFinished(let session, _): "\(session.actualSeconds.durationText) \(session.kind.title.lowercased())"
        }
    }

    private var subtitle: String? {
        switch event {
        case .taskCompleted(_, let category, _): category?.name
        case .habitCompleted: "Habit completed"
        case .focusFinished(let session, let taskTitle): [taskTitle, session.completed ? nil : "interrupted"].dotted
        }
    }

    private var icon: String {
        switch event {
        case .taskCompleted: "work"
        case .habitCompleted(let habit, _): habit.icon
        case .focusFinished: "code"
        }
    }

    private var accent: AccentColor {
        switch event {
        case .taskCompleted(_, let category, _): category?.color ?? .purple
        case .habitCompleted(let habit, _): habit.color
        case .focusFinished: .purple
        }
    }
}

private extension HistoryFilter {
    var title: String {
        switch self {
        case .all: "All"
        case .focus: "Focus"
        case .tasks: "Tasks"
        case .habits: "Habits"
        }
    }
}
