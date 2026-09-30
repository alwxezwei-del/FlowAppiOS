import SwiftUI

struct HabitDetailsView: View {
    let habitId: String

    @Environment(HabitService.self) private var habitService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    var body: some View {
        let habit = habitService.habit(id: habitId)

        Screen(title: habit?.name ?? "", onBack: { router.pop() }) {
            if let habit {
                content(habit)
            }
        }
    }

    private func content(_ habit: Habit) -> some View {
        let streaks = habitService.streaks(for: habit)
        let done = habitService.doneDays(of: habit)
        let today = time.today
        let lastDays = (0..<30).map { today.minusDays(29 - $0) }

        return ScrollView {
            VStack(spacing: 16) {
                FlowCard {
                    HStack(spacing: 12) {
                        IconBadge(icon: habit.icon, accent: habit.color)
                        VStack(alignment: .leading) {
                            Text(habit.name).font(.flowTitle2).foregroundStyle(colors.textMain)
                            Text(habit.schedule.title).font(.flowCaption).foregroundStyle(colors.textSecondary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    stat("Current streak", "\(streaks.current) days")
                    stat("Longest streak", "\(streaks.longest) days")
                    stat("Completion rate", streaks.completionRate.percentText)
                }
                .fixedSize(horizontal: false, vertical: true)

                FlowCard {
                    Text("Last 30 days").font(.flowBody2).foregroundStyle(colors.textSecondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 10), spacing: 6) {
                        ForEach(lastDays, id: \.self) { day in
                            dayCell(day, habit: habit, isDone: done.contains(day))
                        }
                    }
                    .padding(.top, 12)
                }

                SecondaryButton(title: "Edit") { router.push(.habitEditor(habitId: habit.id)) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        FlowCard(padding: 12) {
            Text(title).font(.flowCaption).foregroundStyle(colors.textSecondary)
            Spacer(minLength: 0)
            Text(value).font(.flowTitle2).foregroundStyle(colors.textMain)
        }
        .frame(maxHeight: .infinity)
    }

    private func dayCell(_ day: LocalDate, habit: Habit, isDone: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let fill = isDone ? colors.accent(habit.color) : habit.schedule.isScheduled(on: day) ? colors.layer2 : colors.layer1
        return Button { habitService.setDone(habit.id, on: day, !isDone) } label: {
            shape.fill(fill)
                .overlay(shape.strokeBorder(colors.divider, lineWidth: 0.5))
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.fullText)
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }
}
