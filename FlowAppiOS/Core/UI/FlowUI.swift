import SwiftUI

/** Screen top bar */
struct FlowTopBar<Actions: View>: View {
    let title: String
    var onBack: (() -> Void)? = nil
    @ViewBuilder var actions: () -> Actions

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if let onBack {
                FlowIconButton(systemName: "arrow.left", accessibilityLabel: "Back", tint: colors.iconMain, action: onBack)
                    .padding(.leading, FlowSpacers.x4)
            }
            Text(title)
                .font(FlowTypography.title1)
                .foregroundStyle(colors.textMain)
                .lineLimit(1)
                .padding(.leading, onBack == nil ? FlowSpacers.x16 : FlowSpacers.x4)
            Spacer(minLength: FlowSpacers.x8)
            actions().padding(.trailing, FlowSpacers.x4)
        }
        .frame(height: 64)
        .background(colors.layer0)
    }
}

extension FlowTopBar where Actions == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

/** Section header with an optional trailing text */
struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var onTrailingClick: (() -> Void)? = nil

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(FlowTypography.title2)
                .foregroundStyle(colors.textMain)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                if let onTrailingClick {
                    Button(action: onTrailingClick) {
                        Text(trailing).font(FlowTypography.body2).foregroundStyle(colors.primary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(trailing).font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
                }
            }
        }
    }
}

/** Empty list state. */
struct EmptyState: View {
    let title: String
    var subtitle: String? = nil

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(spacing: FlowSpacers.x8) {
            Text(title)
                .font(FlowTypography.title2)
                .foregroundStyle(colors.textMain)
            if let subtitle {
                Text(subtitle)
                    .font(FlowTypography.body2)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, FlowSpacers.x32)
        .padding(.horizontal, FlowSpacers.x24)
    }
}

/**
 * Task row shared by Today and Tasks: checkbox, title, "category · estimate" subtitle.
 */
struct TaskRow<Trailing: View>: View {
    let title: String
    let completed: Bool
    /** e.g. `Work · 45m`, `nil` = none */
    var subtitle: String? = nil
    /** focus progress `0...1`, shown while the task is in progress */
    var progress: Double = 0
    var accent: AccentColor = .default
    var onClick: (() -> Void)? = nil
    let onToggle: (Bool) -> Void
    /** optional trailing actions slot */
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: FlowSpacers.x12) {
            FlowCheckCircle(checked: completed, accessibilityLabel: title, accent: colors.accent(accent), onCheckedChange: onToggle)
            VStack(alignment: .leading, spacing: FlowSpacers.x2) {
                Text(title)
                    .font(FlowTypography.body1)
                    .foregroundStyle(completed ? colors.textTertiary : colors.textMain)
                    .strikethrough(completed)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle)
                        .font(FlowTypography.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
                if !completed && progress > 0 {
                    FlowProgressBar(progress: progress, color: colors.accent(accent), height: FlowSpacers.x4)
                        .padding(.top, FlowSpacers.x4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, FlowSpacers.x12)
        .contentShape(Rectangle())
        .onTapGesture { onClick?() }
    }
}

extension TaskRow where Trailing == EmptyView {
    init(title: String, completed: Bool, subtitle: String? = nil, progress: Double = 0, accent: AccentColor = .default, onClick: (() -> Void)? = nil, onToggle: @escaping (Bool) -> Void) {
        self.init(title: title, completed: completed, subtitle: subtitle, progress: progress, accent: accent, onClick: onClick, onToggle: onToggle) { EmptyView() }
    }
}

/**
 * Habit row: icon, name, day progress and checkbox.
 */
struct HabitRow<Trailing: View>: View {
    let name: String
    let iconKey: String
    let completed: Bool
    var accent: AccentColor = .default
    /** e.g. `1/1 · 60 min` or `12 day streak` */
    var subtitle: String? = nil
    var onClick: (() -> Void)? = nil
    let onToggle: (Bool) -> Void
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: FlowSpacers.x12) {
            FlowIconBadge(iconKey: iconKey, accent: accent)
            VStack(alignment: .leading, spacing: FlowSpacers.x2) {
                Text(name)
                    .font(FlowTypography.body1)
                    .foregroundStyle(colors.textMain)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            FlowCheckCircle(checked: completed, accessibilityLabel: name, accent: colors.accent(accent), onCheckedChange: onToggle)
            trailing()
        }
        .padding(.vertical, FlowSpacers.x8)
        .contentShape(Rectangle())
        .onTapGesture { onClick?() }
    }
}

extension HabitRow where Trailing == EmptyView {
    init(name: String, iconKey: String, completed: Bool, accent: AccentColor = .default, subtitle: String? = nil, onClick: (() -> Void)? = nil, onToggle: @escaping (Bool) -> Void) {
        self.init(name: name, iconKey: iconKey, completed: completed, accent: accent, subtitle: subtitle, onClick: onClick, onToggle: onToggle) { EmptyView() }
    }
}

struct FlowMoreMenu<Content: View>: View {
    let accessibilityLabel: String
    @ViewBuilder let content: () -> Content

    @Environment(\.flowColors) private var colors

    var body: some View {
        Menu(content: content) {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .font(.system(size: 20))
                .foregroundStyle(colors.iconSecondary)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct FlowScaffold<TopBar: View, Content: View>: View {
    @ViewBuilder var topBar: () -> TopBar
    var fab: FabConfig? = nil
    @ViewBuilder let content: () -> Content

    struct FabConfig {
        let accessibilityLabel: String
        let onClick: () -> Void
    }

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            topBar()
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottomTrailing) {
            if let fab {
                Button(action: fab.onClick) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(colors.textOnAccent)
                        .frame(width: 56, height: 56)
                        .background(colors.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(fab.accessibilityLabel)
                .padding(FlowSpacers.x16)
            }
        }
        .background(colors.layer0.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension FlowScaffold where TopBar == EmptyView {
    init(fab: FabConfig? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(topBar: { EmptyView() }, fab: fab, content: content)
    }
}

extension View {
    func flowListPadding() -> some View {
        padding(.horizontal, FlowSpacers.x16)
            .padding(.top, FlowSpacers.x8)
            .padding(.bottom, FlowSpacers.x24)
    }
}
