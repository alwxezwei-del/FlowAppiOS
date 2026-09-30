import SwiftUI

struct FlowCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    @Environment(\.colors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.layer1, in: shape)
            .overlay(shape.strokeBorder(colors.divider, lineWidth: 0.5))
    }
}

struct FlowChip: View {
    let title: String
    let isSelected: Bool
    var accent: Color?
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        let accent = accent ?? colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            Text(title)
                .font(.flowBody2)
                .foregroundStyle(isSelected ? colors.textOnAccent : colors.textSecondary)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? accent : colors.layer2, in: shape)
                .overlay(shape.strokeBorder(isSelected ? accent : colors.divider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A titled, horizontally scrolling row of chips, used in editors and settings.
struct ChipGroup<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    @Environment(\.colors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.flowBody2).foregroundStyle(colors.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content }
            }
            .scrollClipDisabled()
        }
    }
}

struct SegmentedPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    @Environment(\.colors) private var colors

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.flowBody2)
                        .foregroundStyle(isSelected ? colors.textMain : colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? colors.layer3 : colors.layer2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(colors.layer2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: selection)
    }
}

struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.flowButton)
                .foregroundStyle(isEnabled ? colors.textOnAccent : colors.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isEnabled ? colors.primary : colors.layer2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressedOpacity())
        .disabled(!isEnabled)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.flowButton)
                .lineLimit(1)
                .foregroundStyle(colors.textMain)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(colors.layer2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressedOpacity())
    }
}

struct TextButton: View {
    let title: String
    var isDestructive = false
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.flowButton)
                .foregroundStyle(isDestructive ? colors.error : colors.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
        }
        .buttonStyle(PressedOpacity())
    }
}

struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color?
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundStyle(tint ?? colors.iconSecondary)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct PressedOpacity: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct CheckCircle: View {
    let isChecked: Bool
    let label: String
    var accent: Color?
    let action: (Bool) -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        let accent = accent ?? colors.primary
        Button { action(!isChecked) } label: {
            ZStack {
                Circle().fill(isChecked ? accent : .clear)
                Circle().strokeBorder(isChecked ? accent : colors.divider, lineWidth: 2)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(colors.textOnAccent)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isChecked)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color?
    var height: CGFloat = 6

    @Environment(\.colors) private var colors

    var body: some View {
        Capsule()
            .fill(colors.layer2)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color ?? colors.primary)
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.4), value: value)
    }
}

struct ProgressRing<Content: View>: View {
    let value: Double
    var lineWidth: CGFloat = 12
    @ViewBuilder let content: Content

    @Environment(\.colors) private var colors

    var body: some View {
        ZStack {
            Circle().stroke(colors.layer2, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(colors.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: value)
            content
        }
        .padding(lineWidth / 2)
    }
}

struct IconBadge: View {
    let icon: String
    let accent: AccentColor
    var size: CGFloat = 40

    @Environment(\.colors) private var colors

    var body: some View {
        Image(systemName: symbol(for: icon))
            .font(.system(size: size / 2 - 2))
            .foregroundStyle(colors.accent(accent))
            .frame(width: size, height: size)
            .background(colors.accentSurface(accent), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ColorDot: View {
    let color: Color
    let isSelected: Bool
    var size: CGFloat = 36
    let action: () -> Void

    @Environment(\.colors) private var colors

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(isSelected ? colors.textMain : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct Bar: Hashable {
    let label: String
    let value: Double
    let accessibilityText: String
    var isHighlighted = false
}

struct BarChart: View {
    let bars: [Bar]
    var height: CGFloat = 120

    @Environment(\.colors) private var colors

    var body: some View {
        let top = max(bars.map(\.value).max() ?? 0, 0.0001)
        HStack(alignment: .bottom, spacing: bars.count > 12 ? 2 : 6) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                // Empty days still get a sliver so the axis doesn't look broken
                let barHeight = height * max(bar.value / top, 0.02)
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: min(8, barHeight / 2), style: .continuous)
                        .fill(colors.primary.opacity(bar.isHighlighted ? 1 : 0.55))
                        .frame(height: barHeight)
                        .frame(height: height, alignment: .bottom)
                    Text(bar.label)
                        .font(.flowCaption)
                        .foregroundStyle(colors.textTertiary)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(bar.accessibilityText)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: bars)
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder = ""
    var isMultiline = false
    var keyboard = UIKeyboardType.default

    @Environment(\.colors) private var colors
    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.flowBody2).foregroundStyle(colors.textSecondary)
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(colors.textTertiary), axis: isMultiline ? .vertical : .horizontal)
                .lineLimit(isMultiline ? 3...8 : 1...1)
                .font(.flowBody1)
                .foregroundStyle(colors.textMain)
                .keyboardType(keyboard)
                .focused($isFocused)
                .padding(16)
                .background(colors.layer2, in: shape)
                .overlay(shape.strokeBorder(isFocused ? colors.primary : colors.divider, lineWidth: isFocused ? 2 : 1))
        }
    }
}
