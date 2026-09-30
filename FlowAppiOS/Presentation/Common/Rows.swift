import SwiftUI

struct TaskRow<Trailing: View>: View {
    let task: FlowTask
    let category: Category?
    /// Shown under the title, e.g. "Work · 20m / 45m".
    var subtitle: String?
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    @ViewBuilder var trailing: Trailing

    @Environment(\.colors) private var colors

    var body: some View {
        let accent = colors.accent(category?.color ?? .purple)
        HStack(spacing: 12) {
            CheckCircle(isChecked: task.isCompleted, label: task.title, accent: accent, action: onToggle)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.flowBody1)
                    .foregroundStyle(task.isCompleted ? colors.textTertiary : colors.textMain)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.flowCaption).foregroundStyle(colors.textSecondary).lineLimit(1)
                }
                if !task.isCompleted && task.focusProgress > 0 {
                    ProgressBar(value: task.focusProgress, color: accent, height: 4).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

extension TaskRow where Trailing == EmptyView {
    init(task: FlowTask, category: Category?, subtitle: String?, onToggle: @escaping (Bool) -> Void, onTap: @escaping () -> Void) {
        self.init(task: task, category: category, subtitle: subtitle, onToggle: onToggle, onTap: onTap) { EmptyView() }
    }
}

struct HabitRow<Trailing: View>: View {
    let habit: Habit
    let isDone: Bool
    /// e.g. "1/1 · 12 day streak".
    let subtitle: String
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    @ViewBuilder var trailing: Trailing

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: habit.icon, accent: habit.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name).font(.flowBody1).foregroundStyle(colors.textMain).lineLimit(1)
                Text(subtitle).font(.flowCaption).foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CheckCircle(isChecked: isDone, label: habit.name, accent: colors.accent(habit.color), action: onToggle)
            trailing
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

extension HabitRow where Trailing == EmptyView {
    init(habit: Habit, isDone: Bool, subtitle: String, onToggle: @escaping (Bool) -> Void, onTap: @escaping () -> Void) {
        self.init(habit: habit, isDone: isDone, subtitle: subtitle, onToggle: onToggle, onTap: onTap) { EmptyView() }
    }
}
