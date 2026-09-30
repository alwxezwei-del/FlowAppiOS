import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @Binding var selectedTab: FlowTab
    @State private var editingTask: FlowTask?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header
                WeekStrip(selectedDate: $store.selectedDate)
                FocusSummaryCard(minutes: store.focusTodayMinutes, completed: store.completedTodayCount, total: max(store.todayTasks.count + store.completedTodayCount, 1))
                tasksSection
                habitsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $editingTask) { task in TaskEditorScreen(task: task) }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(flow.textMain)
                Text(store.selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundStyle(flow.textSecondary)
            }
            Spacer()
            NavigationLink { HistoryScreen() } label: { Image(systemName: "clock.arrow.circlepath") }.buttonStyle(IconButtonStyle())
            NavigationLink { SettingsScreen() } label: { Image(systemName: "gearshape") }.buttonStyle(IconButtonStyle())
        }
        .padding(.top, 6)
    }

    private var tasksSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Today's tasks", trailing: "\(store.completedTodayCount)/\(store.todayTasks.count + store.completedTodayCount)")
            FlowCard(padding: 12) {
                if store.todayTasks.isEmpty {
                    EmptyState(icon: "checkmark.seal", title: "No tasks for this day", subtitle: "Create a task or move one to today.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.todayTasks) { task in
                            TaskRowView(task: task, category: store.category(for: task.categoryID), onToggle: { store.toggleTask(task, completed: $0) }, onTap: { editingTask = task })
                        }
                    }
                }
            }
        }
    }

    private var habitsSection: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Habits", trailing: "Manage") { selectedTab = .tasks }
            FlowCard(padding: 12) {
                VStack(spacing: 0) {
                    ForEach(store.habits) { habit in
                        HabitRowView(habit: habit, date: store.selectedDate) { store.toggleHabit(habit, on: store.selectedDate, completed: $0) }
                    }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
}

struct WeekStrip: View {
    @Environment(\.flow) private var flow
    @Binding var selectedDate: Date

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.flowDayKey) { day in
                let selected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { selectedDate = day } } label: {
                    VStack(spacing: 7) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.system(size: 13))
                        Text(day.formatted(.dateTime.day())).font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(selected ? .white : flow.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selected ? flow.primary : flow.layer1, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? Color.clear : flow.divider, lineWidth: 0.7))
                }.buttonStyle(.plain)
            }
        }
    }

    private var days: [Date] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).map { start.addingDays($0) }
    }
}

struct FocusSummaryCard: View {
    @Environment(\.flow) private var flow
    var minutes: Int
    var completed: Int
    var total: Int

    var body: some View {
        FlowCard {
            HStack(spacing: 16) {
                ProgressRing(progress: Double(completed) / Double(max(total, 1)), stroke: 8) {
                    VStack(spacing: 2) {
                        Text("\(completed)/\(total)").font(.system(size: 18, weight: .semibold))
                        Text("tasks").font(.system(size: 11)).foregroundStyle(flow.textSecondary)
                    }
                }
                .frame(width: 82, height: 82)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus today").font(.system(size: 14)).foregroundStyle(flow.textSecondary)
                    Text(formatMinutes(minutes)).font(.system(size: 32, weight: .medium)).foregroundStyle(flow.textMain)
                    Text(minutes == 0 ? "Start a session to build momentum" : "+12% vs previous period")
                        .font(.system(size: 13)).foregroundStyle(minutes == 0 ? flow.textTertiary : flow.success)
                }
                Spacer()
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct EmptyState: View {
    @Environment(\.flow) private var flow
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 24, weight: .semibold)).foregroundStyle(flow.primary)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(flow.textMain)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(flow.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
