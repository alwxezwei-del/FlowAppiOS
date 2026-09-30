import SwiftUI

struct HabitsView: View {
    @Environment(HabitService.self) private var habitService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time

    var body: some View {
        let today = time.today
        let all = habitService.allHabits
        let active = all.filter { !$0.archived }

        Screen(title: "Habits", onBack: { router.pop() }, onAdd: { router.push(.habitEditor(habitId: nil)) }, addLabel: "New habit") {
            ScrollContent(bottomInset: 56) {
                if all.isEmpty {
                    FlowCard { EmptyState(title: "No habits yet", subtitle: "Add a habit and start building a streak.") }
                }
                section("Today", active.filter { $0.schedule.isScheduled(on: today) }, today: today)
                section("Other days", active.filter { !$0.schedule.isScheduled(on: today) }, today: today)
                section("Archived", all.filter(\.archived), today: today)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ habits: [Habit], today: LocalDate) -> some View {
        if !habits.isEmpty {
            SectionHeader(title: title)
            ForEach(habits) { habit in
                let streak = habitService.streaks(for: habit).current
                FlowCard(padding: 12) {
                    HabitRow(
                        habit: habit,
                        isDone: habitService.isDone(habit, on: today),
                        subtitle: ["\(habitService.completedCount(habit, on: today))/\(habit.targetPerDay)", streak > 0 ? "\(streak) day streak" : nil].dotted ?? "",
                        onToggle: { habitService.setDone(habit.id, on: today, $0) },
                        onTap: { router.push(.habitDetails(habitId: habit.id)) }
                    ) {
                        MoreMenu {
                            Button(habit.archived ? "Restore" : "Archive", systemImage: habit.archived ? "archivebox.fill" : "archivebox") {
                                habitService.setArchived(habit.id, !habit.archived)
                            }
                            Button("Delete", role: .destructive) { habitService.delete(habit.id) }
                        }
                    }
                }
            }
        }
    }
}
