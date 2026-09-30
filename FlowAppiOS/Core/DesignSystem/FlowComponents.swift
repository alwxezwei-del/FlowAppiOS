import SwiftUI

/** Base card */
struct FlowCard<Content: View>: View {
    var contentPadding: CGFloat = FlowSpacers.x16
    var onClick: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.flowColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FlowRadius.x18, style: .continuous)
        let card = VStack(alignment: .leading, spacing: 0, content: content)
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.layer1, in: shape)
            .overlay(shape.strokeBorder(colors.divider, lineWidth: hairline))

        if let onClick {
            Button(action: onClick) { card.contentShape(shape) }.buttonStyle(.plain)
        } else {
            card
        }
    }
}

/** Selection chip */
struct FlowChip: View {
    let text: String
    let selected: Bool
    var accent: Color? = nil
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        let accent = accent ?? colors.primary
        let shape = RoundedRectangle(cornerRadius: FlowRadius.x12, style: .continuous)
        Button(action: onClick) {
            Text(text)
                .font(FlowTypography.body2)
                .foregroundStyle(selected ? colors.textOnAccent : colors.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, FlowSpacers.x12)
                .padding(.vertical, FlowSpacers.x8)
                .background(selected ? accent : colors.layer2, in: shape)
                .overlay(shape.strokeBorder(selected ? accent : colors.divider, lineWidth: hairline))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/** Segmented control */
struct FlowSegmentedControl: View {
    let items: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        HStack(spacing: FlowSpacers.x4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                let selected = index == selectedIndex
                Button { onSelect(index) } label: {
                    Text(title)
                        .font(FlowTypography.body2)
                        .foregroundStyle(selected ? colors.textMain : colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FlowSpacers.x8)
                        .background(selected ? colors.layer3 : colors.layer2, in: RoundedRectangle(cornerRadius: FlowRadius.x8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(FlowSpacers.x4)
        .background(colors.layer2, in: RoundedRectangle(cornerRadius: FlowRadius.x12, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
    }
}

/** Primary action button */
struct FlowPrimaryButton: View {
    let text: String
    var enabled = true
    var icon: String? = nil
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: FlowSpacers.x8) {
                if let icon { Image(systemName: icon) }
                Text(text).font(FlowTypography.button).lineLimit(1)
            }
            .foregroundStyle(enabled ? colors.textOnAccent : colors.textTertiary)
            .padding(.horizontal, FlowSpacers.x24)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(enabled ? colors.primary : colors.layer2, in: RoundedRectangle(cornerRadius: FlowRadius.x14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/** Secondary button on layer2 surface */
struct FlowSecondaryButton: View {
    let text: String
    var enabled = true
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .font(FlowTypography.button)
                .lineLimit(1)
                .foregroundStyle(enabled ? colors.textMain : colors.textTertiary)
                .padding(.horizontal, FlowSpacers.x24)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(colors.layer2, in: RoundedRectangle(cornerRadius: FlowRadius.x14, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

/** Text button for destructive and minor actions */
struct FlowTextButton: View {
    let text: String
    var destructive = false
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .font(FlowTypography.button)
                .foregroundStyle(destructive ? colors.error : colors.textSecondary)
                .padding(.horizontal, FlowSpacers.x12)
                .frame(minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/** Round checkbox for tasks and habits */
struct FlowCheckCircle: View {
    let checked: Bool
    let accessibilityLabel: String
    var size: CGFloat = 26
    var accent: Color? = nil
    let onCheckedChange: (Bool) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        let accent = accent ?? colors.primary
        Button { onCheckedChange(!checked) } label: {
            ZStack {
                Circle().fill(checked ? accent : Color.clear)
                Circle().strokeBorder(checked ? accent : colors.divider, lineWidth: 2)
                if checked {
                    Image(systemName: FlowIcons.check)
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(colors.textOnAccent)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: checked)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/** Horizontal progress bar */
struct FlowProgressBar: View {
    let progress: Double
    var color: Color? = nil
    var height: CGFloat = 6

    @Environment(\.flowColors) private var colors

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        Capsule()
            .fill(colors.layer2)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color ?? colors.primary)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.4), value: clamped)
    }
}

/** Timer progress ring */
struct FlowProgressRing<Content: View>: View {
    let progress: Double
    var strokeWidth: CGFloat = 10
    var color: Color? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.flowColors) private var colors

    var body: some View {
        ZStack {
            Circle()
                .stroke(colors.layer2, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color ?? colors.primary, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                // 12 o'clock.
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: progress)
            content()
        }
        .padding(strokeWidth / 2)
    }
}

/** Square habit/category icon on a tinted background */
struct FlowIconBadge: View {
    let iconKey: String
    let accent: AccentColor
    var size: CGFloat = 40

    @Environment(\.flowColors) private var colors

    var body: some View {
        Image(systemName: FlowIcons.byKey(iconKey))
            .font(.system(size: size / 2 - 2))
            .foregroundStyle(colors.accent(accent))
            .frame(width: size, height: size)
            .background(colors.accentSurface(accent), in: RoundedRectangle(cornerRadius: FlowRadius.x12, style: .continuous))
            .accessibilityHidden(true)
    }
}

/** Chart bar */
struct FlowBar: Hashable {
    let label: String
    let value: Double
    let description: String
    var highlighted = false
}

/** Daily focus bar chart */
struct FlowBarChart: View {
    let bars: [FlowBar]
    var barHeight: CGFloat = 120
    var color: Color? = nil

    @Environment(\.flowColors) private var colors

    var body: some View {
        let color = color ?? colors.primary
        let maxValue = bars.map(\.value).max().flatMap { $0 > 0 ? $0 : nil } ?? 1

        HStack(alignment: .bottom, spacing: bars.count > 12 ? FlowSpacers.x2 : FlowSpacers.x6) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                let fraction = max(min(bar.value / maxValue, 1), Self.minVisibleFraction)
                VStack(spacing: FlowSpacers.x6) {
                    VStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: min(FlowRadius.x8, barHeight * fraction / 2), style: .continuous)
                            .fill(bar.highlighted ? color : color.opacity(Self.inactiveAlpha))
                            .frame(height: barHeight * fraction)
                    }
                    .frame(height: barHeight)
                    Text(bar.label)
                        .font(FlowTypography.caption)
                        .foregroundStyle(colors.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(bar.description)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: bars)
    }

    /** Empty days still render a thin bar */
    private static let minVisibleFraction = 0.02
    private static let inactiveAlpha = 0.55
}

/** Text field with a static label above it */
struct FlowTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String? = nil
    var singleLine = true
    var minLines = 1
    var keyboardType: UIKeyboardType = .default

    @Environment(\.flowColors) private var colors
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FlowSpacers.x6) {
            Text(label).font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
            let shape = RoundedRectangle(cornerRadius: FlowRadius.x12, style: .continuous)
            TextField(
                "",
                text: $text,
                prompt: placeholder.map { Text($0).foregroundStyle(colors.textTertiary) },
                axis: singleLine ? .horizontal : .vertical
            )
            .lineLimit(singleLine ? 1...1 : minLines...max(minLines, 8))
            .font(FlowTypography.body1)
            .foregroundStyle(colors.textMain)
            .keyboardType(keyboardType)
            .focused($focused)
            .padding(.horizontal, FlowSpacers.x16)
            .padding(.vertical, FlowSpacers.x16)
            .background(colors.layer2, in: shape)
            .overlay(shape.strokeBorder(focused ? colors.primary : colors.divider, lineWidth: focused ? 2 : 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FlowSwitch: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String

    @Environment(\.flowColors) private var colors

    var body: some View {
        Toggle(accessibilityLabel, isOn: $isOn)
            .labelsHidden()
            .tint(colors.primary)
    }
}
