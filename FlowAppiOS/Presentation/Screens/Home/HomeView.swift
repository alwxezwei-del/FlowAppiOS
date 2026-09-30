import SwiftUI

struct HomeView: View {
    @Environment(TaskService.self) private var taskService
    @Environment(HabitService.self) private var habitService
    @Environment(FocusService.self) private var focusService
    @Environment(SettingsService.self) private var settingsService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    @State private var selectedDate: LocalDate?

    var body: some View {
        let today = time.today
        let date = selectedDate ?? today
        let tasks = taskService.tasks(on: date)
        let habits = habitService.habits(scheduledOn: date)
        let completed = tasks.filter(\.isCompleted).count

        Screen {
            ScrollContent(spacing: 16) {
                header(date: date)

                WeekStrip(
                    days: (0..<7).map(date.startOfWeek(settingsService.settings.startOfWeek).plusDays),
                    selected: date,
                    today: today
                ) { selectedDate = $0 }

                FocusSummaryCard(
                    seconds: focusService.focusSeconds(in: DateRange(start: date, end: date)),
                    previousSeconds: focusService.focusSeconds(in: DateRange(start: date.minusDays(1), end: date.minusDays(1))),
                    progress: "\(completed) / \(tasks.count) completed"
                )

                SectionHeader(title: "Tasks", trailing: tasks.isEmpty ? nil : "\(completed)/\(tasks.count)")
                if tasks.isEmpty {
                    FlowCard { EmptyState(title: "No tasks for this day", subtitle: "Add one from the Tasks tab to plan your day.") }
                } else {
                    FlowCard(padding: 12) {
                        ForEach(tasks) { task in
                            let category = taskService.category(id: task.categoryId)
                            TaskRow(
                                task: task,
                                category: category,
                                subtitle: [category?.name, task.focusText].dotted,
                                onToggle: { taskService.setCompleted(task.id, $0) },
                                onTap: { router.push(.taskEditor(taskId: task.id)) }
                            )
                        }
                    }
                }

                SectionHeader(title: "Habits", trailing: "Manage") { router.push(.habits) }
                if habits.isEmpty {
                    FlowCard { EmptyState(title: "No habits scheduled", subtitle: "Create a habit to start building a streak.") }
                } else {
                    ForEach(habits) { habit in
                        FlowCard(padding: 12) {
                            HabitRow(
                                habit: habit,
                                isDone: habitService.isDone(habit, on: date),
                                subtitle: habitSubtitle(habit, on: date),
                                // Marks the selected day, so past days can be filled in
                                onToggle: { habitService.setDone(habit.id, on: date, $0) },
                                onTap: { router.push(.habitDetails(habitId: habit.id)) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func header(date: LocalDate) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.flowTitle1).foregroundStyle(colors.textMain)
                Text(date.fullText).font(.flowBody2).foregroundStyle(colors.textSecondary)
            }
            Spacer()
            IconButton(systemName: "clock.arrow.circlepath", label: "History") { router.push(.history) }
            IconButton(systemName: "gearshape", label: "Settings") { router.push(.settings) }
        }
    }

    private var greeting: String {
        switch time.calendar.component(.hour, from: time.now()) {
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    private func habitSubtitle(_ habit: Habit, on date: LocalDate) -> String {
        let streak = habitService.streaks(for: habit).current
        return ["\(habitService.completedCount(habit, on: date))/\(habit.targetPerDay)", streak > 0 ? "\(streak) day streak" : nil].dotted ?? ""
    }
}

private struct WeekStrip: View {
    let days: [LocalDate]
    let selected: LocalDate
    let today: LocalDate
    let onSelect: (LocalDate) -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelected = day == selected
                Button { onSelect(day) } label: {
                    VStack(spacing: 6) {
                        Text(day.initial).font(.flowCaption).foregroundStyle(colors.textTertiary)
                        Text("\(day.day)")
                            .font(.flowBody2)
                            .foregroundStyle(isSelected ? colors.textOnAccent : day == today ? colors.primary : colors.textMain)
                            .frame(width: 32, height: 32)
                            .background(isSelected ? colors.primary : .clear, in: Circle())
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullText)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

private struct FocusSummaryCard: View {
    let seconds: Int
    let previousSeconds: Int
    let progress: String

    @Environment(\.colors) private var colors

    var body: some View {
        FlowCard {
            Text("Today focus").font(.flowBody2).foregroundStyle(colors.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(seconds.durationText).font(.flowDisplay).foregroundStyle(colors.textMain)
                if previousSeconds > 0 {
                    let trend = Double(seconds - previousSeconds) / Double(previousSeconds)
                    Label(trend.signedPercentText, systemImage: trend >= 0 ? "arrow.up" : "arrow.down")
                        .font(.flowCaption)
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(trend >= 0 ? colors.success : colors.error)
                }
            }
            Text(progress).font(.flowBody2).foregroundStyle(colors.textSecondary)
        }
    }
}
