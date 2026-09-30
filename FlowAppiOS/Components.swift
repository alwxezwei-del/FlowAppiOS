import SwiftUI

struct FlowCard<Content: View>: View {
    @Environment(\.flow) private var flow
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(padding)
            .background(flow.layer1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(flow.divider, lineWidth: 0.7))
    }
}

struct FlowTopBar: View {
    @Environment(\.flow) private var flow
    var title: String
    var back: (() -> Void)? = nil
    var actions: [TopBarAction] = []

    var body: some View {
        HStack(spacing: 10) {
            if let back {
                Button(action: back) { Image(systemName: "chevron.left") }
                    .buttonStyle(IconButtonStyle())
            }
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(flow.textMain)
            Spacer()
            ForEach(actions) { action in
                Button(action: action.action) { Image(systemName: action.icon) }
                    .buttonStyle(IconButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct TopBarAction: Identifiable {
    let id = UUID()
    var icon: String
    var action: () -> Void
}

struct SectionHeader: View {
    @Environment(\.flow) private var flow
    var title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(flow.textMain)
            Spacer()
            if let trailing {
                Button(trailing, action: action ?? {})
                    .disabled(action == nil)
                    .font(.system(size: 14))
                    .foregroundStyle(action == nil ? flow.textSecondary : flow.primary)
            }
        }
    }
}

struct FlowChip: View {
    @Environment(\.flow) private var flow
    var title: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? flow.textMain : flow.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? flow.layer3 : flow.layer2, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct FlowIconBadge: View {
    @Environment(\.flow) private var flow
    var icon: String
    var accent: AccentColor
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(accent.color(for: flow.isDark ? .dark : .light))
            .frame(width: size, height: size)
            .background(accent.color(for: flow.isDark ? .dark : .light).opacity(flow.isDark ? 0.18 : 0.14), in: RoundedRectangle(cornerRadius: size * 0.33, style: .continuous))
    }
}

struct FlowCheckCircle: View {
    @Environment(\.flow) private var flow
    var checked: Bool
    var accent: AccentColor
    var action: (Bool) -> Void

    var body: some View {
        Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { action(!checked) } } label: {
            ZStack {
                Circle().stroke(checked ? accent.color(for: flow.isDark ? .dark : .light) : flow.divider, lineWidth: 2)
                if checked {
                    Circle().fill(accent.color(for: flow.isDark ? .dark : .light))
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
        }.buttonStyle(.plain)
    }
}

struct FlowProgressBar: View {
    @Environment(\.flow) private var flow
    var value: Double
    var color: Color? = nil
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(flow.layer2)
                Capsule().fill(color ?? flow.primary).frame(width: max(0, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

struct ProgressRing<Content: View>: View {
    @Environment(\.flow) private var flow
    var progress: Double
    var stroke: CGFloat = 10
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle().stroke(flow.layer2, lineWidth: stroke)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(flow.primary, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            content()
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.flow) private var flow
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(flow.textMain)
            .frame(width: 42, height: 42)
            .background(flow.layer2, in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.flow) private var flow
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(flow.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct FlowSegmentedControl<T: Hashable>: View {
    @Environment(\.flow) private var flow
    var items: [T]
    @Binding var selection: T
    var title: (T) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button { withAnimation(.easeInOut(duration: 0.2)) { selection = item } } label: {
                    Text(title(item))
                        .font(.system(size: 14, weight: selection == item ? .semibold : .regular))
                        .foregroundStyle(selection == item ? flow.textMain : flow.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selection == item ? flow.layer3 : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(flow.layer2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TaskRowView: View {
    @Environment(\.flow) private var flow
    var task: FlowTask
    var category: FlowCategory?
    var onToggle: (Bool) -> Void
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                FlowCheckCircle(checked: task.isCompleted, accent: category?.color ?? .purple, action: onToggle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 16))
                        .foregroundStyle(task.isCompleted ? flow.textTertiary : flow.textMain)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(flow.textSecondary)
                    if !task.isCompleted && task.progress > 0 {
                        FlowProgressBar(value: task.progress, color: (category?.color ?? .purple).color(for: flow.isDark ? .dark : .light), height: 4)
                            .padding(.top, 4)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(flow.textTertiary)
            }
            .padding(.vertical, 12)
        }.buttonStyle(.plain)
    }

    private var subtitle: String {
        let categoryName = category?.name ?? "Inbox"
        let estimate = task.estimateMinutes > 0 ? " · \(task.estimateMinutes)m" : ""
        return categoryName + estimate
    }
}

struct HabitRowView: View {
    @Environment(\.flow) private var flow
    var habit: FlowHabit
    var date: Date
    var onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            FlowIconBadge(icon: habit.icon, accent: habit.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name).font(.system(size: 16)).foregroundStyle(flow.textMain)
                Text(habit.isCompleted(on: date) ? "1/\(habit.targetPerDay) · done" : "0/\(habit.targetPerDay) · today")
                    .font(.system(size: 13)).foregroundStyle(flow.textSecondary)
            }
            Spacer()
            FlowCheckCircle(checked: habit.isCompleted(on: date), accent: habit.color, action: onToggle)
        }.padding(.vertical, 8)
    }
}
