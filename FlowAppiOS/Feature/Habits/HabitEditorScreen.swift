import SwiftUI
import Observation

/**
 * Habit editor state.
 */
struct HabitEditorUiState {
    var isEditing = false
    var name = ""
    var icon = FlowIconKey.default
    var color: AccentColor = .default
    var daily = true
    var selectedDays = Set(DayOfWeek.allCases)
    var targetPerDay = 1
    var reminderMinuteOfDay: Int?
    var note = ""

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (daily || !selectedDays.isEmpty)
    }
}

@MainActor
@Observable
final class HabitEditorViewModel {
    var state: HabitEditorUiState

    @ObservationIgnored private let container: AppContainer
    @ObservationIgnored private let habitId: String?

    init(container: AppContainer, habitId: String?) {
        self.container = container
        self.habitId = habitId

        var state = HabitEditorUiState(isEditing: habitId != nil)
        if let habit = container.database.habit(id: habitId) {
            state.name = habit.name
            state.icon = habit.icon
            state.color = habit.color
            if case .selectedDays(let days) = habit.schedule {
                state.daily = false
                state.selectedDays = days
            }
            state.targetPerDay = habit.targetPerDay
            state.reminderMinuteOfDay = habit.reminderMinuteOfDay
            state.note = habit.note ?? ""
        }
        self.state = state
    }

    func toggleDay(_ day: DayOfWeek) {
        if state.selectedDays.contains(day) { state.selectedDays.remove(day) } else { state.selectedDays.insert(day) }
    }

    func changeTarget(_ delta: Int) {
        state.targetPerDay = min(max(state.targetPerDay + delta, Self.minTarget), Self.maxTarget)
    }

    /** - Returns: true when the screen should close */
    func save() -> Bool {
        guard state.canSave else { return false }
        let database = container.database
        let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = state.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let schedule: HabitSchedule = state.daily ? .daily : .selectedDays(state.selectedDays)

        if var habit = database.habit(id: habitId) {
            habit.name = name
            habit.icon = state.icon
            habit.color = state.color
            habit.schedule = schedule
            habit.targetPerDay = state.targetPerDay
            habit.reminderMinuteOfDay = state.reminderMinuteOfDay
            habit.note = note.isEmpty ? nil : note
            database.updateHabit(habit)
        } else {
            database.createHabit(Habit(
                name: name,
                icon: state.icon,
                color: state.color,
                schedule: schedule,
                targetPerDay: state.targetPerDay,
                reminderMinuteOfDay: state.reminderMinuteOfDay,
                note: note.isEmpty ? nil : note,
                createdAt: container.timeProvider.now()
            ))
        }
        return true
    }

    func delete() {
        guard let habitId else { return }
        container.database.deleteHabit(id: habitId)
    }

    private static let minTarget = 1
    private static let maxTarget = 20
}

/** Create/edit habit screen */
struct HabitEditorScreen: View {
    private let router: AppRouter
    @State private var viewModel: HabitEditorViewModel
    @State private var timePickerVisible = false

    @Environment(\.flowColors) private var colors

    init(container: AppContainer, habitId: String?) {
        router = container.router
        _viewModel = State(initialValue: HabitEditorViewModel(container: container, habitId: habitId))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let state = viewModel.state

        FlowScaffold(topBar: {
            FlowTopBar(title: state.isEditing ? "Edit habit" : "New habit", onBack: router.navigateUp) {
                if state.isEditing {
                    FlowTextButton(text: "Delete", destructive: true) {
                        viewModel.delete()
                        // Details of a deleted habit make no sense, go back past them
                        router.navigateUp()
                        router.navigateUp()
                    }
                }
            }
        }) {
            ScrollView {
                VStack(alignment: .leading, spacing: FlowSpacers.x20) {
                    EditorSection(title: "Icon") {
                        ForEach(FlowIconKey.all, id: \.self) { icon in
                            IconOption(icon: icon, accent: state.color, selected: state.icon == icon) { viewModel.state.icon = icon }
                        }
                    }

                    FlowTextField(label: "Name", text: $viewModel.state.name, placeholder: "e.g. Read")

                    EditorSection(title: "Color") {
                        ForEach(AccentColor.allCases, id: \.self) { accent in
                            ColorOption(color: colors.accent(accent), selected: state.color == accent, size: 36) { viewModel.state.color = accent }
                        }
                    }

                    EditorSection(title: "Schedule") {
                        FlowChip(text: "Every day", selected: state.daily) { viewModel.state.daily = true }
                        FlowChip(text: "Selected days", selected: !state.daily) { viewModel.state.daily = false }
                    }

                    if !state.daily {
                        EditorSection(title: "") {
                            ForEach(DayOfWeek.allCases, id: \.self) { day in
                                FlowChip(text: day.shortName.uppercased(), selected: state.selectedDays.contains(day)) { viewModel.toggleDay(day) }
                            }
                        }
                    }

                    TargetStepper(target: state.targetPerDay, onChange: viewModel.changeTarget)

                    ReminderRow(
                        minuteOfDay: state.reminderMinuteOfDay,
                        onToggle: { viewModel.state.reminderMinuteOfDay = $0 ? Self.defaultReminderMinute : nil },
                        onPickTime: { timePickerVisible = true }
                    )

                    FlowTextField(label: "Notes (optional)", text: $viewModel.state.note, placeholder: "e.g. Work on personal project", singleLine: false, minLines: 3)

                    FlowPrimaryButton(text: "Save", enabled: state.canSave) {
                        if viewModel.save() { router.navigateUp() }
                    }
                }
                .padding(.horizontal, FlowSpacers.x16)
                .padding(.vertical, FlowSpacers.x8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $timePickerVisible) {
            ReminderTimeSheet(minuteOfDay: state.reminderMinuteOfDay ?? Self.defaultReminderMinute) {
                viewModel.state.reminderMinuteOfDay = $0
                timePickerVisible = false
            } onDismiss: {
                timePickerVisible = false
            }
        }
    }

    /** 19:00 default reminder. */
    private static let defaultReminderMinute = 19 * 60
}

private struct IconOption: View {
    let icon: String
    let accent: AccentColor
    let selected: Bool
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            FlowIconBadge(iconKey: icon, accent: accent)
                .overlay(
                    RoundedRectangle(cornerRadius: FlowRadius.x12, style: .continuous)
                        .strokeBorder(selected ? colors.accent(accent) : colors.divider, lineWidth: selected ? 2 : hairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ColorOption: View {
    let color: Color
    let selected: Bool
    var size: CGFloat = 36
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(selected ? colors.textMain : Color.clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct TargetStepper: View {
    let target: Int
    let onChange: (Int) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: FlowSpacers.x8) {
            Text("Target").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
            HStack(spacing: FlowSpacers.x12) {
                FlowIconButton(systemName: "minus", accessibilityLabel: "Decrease target", tint: colors.iconSecondary) { onChange(-1) }
                Text("\(target)").font(FlowTypography.title2).foregroundStyle(colors.textMain)
                FlowIconButton(systemName: "plus", accessibilityLabel: "Increase target", tint: colors.iconSecondary) { onChange(1) }
                Text("time(s) per day").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
            }
        }
    }
}

private struct ReminderRow: View {
    let minuteOfDay: Int?
    let onToggle: (Bool) -> Void
    let onPickTime: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: FlowSpacers.x8) {
            Text("Reminder (optional)").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
            HStack(spacing: FlowSpacers.x12) {
                if let minuteOfDay {
                    FlowChip(text: formatTime(minuteOfDay: minuteOfDay), selected: true, onClick: onPickTime)
                }
                Spacer()
                FlowSwitch(isOn: Binding(get: { minuteOfDay != nil }, set: onToggle), accessibilityLabel: "Reminder")
            }
        }
    }
}

private struct ReminderTimeSheet: View {
    let onConfirm: (Int) -> Void
    let onDismiss: () -> Void
    @State private var selection: Date

    @Environment(\.flowColors) private var colors

    init(minuteOfDay: Int, onConfirm: @escaping (Int) -> Void, onDismiss: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        let calendar = Calendar(identifier: .gregorian)
        _selection = State(initialValue: calendar.date(from: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60)) ?? Date())
    }

    var body: some View {
        VStack(spacing: FlowSpacers.x8) {
            DatePicker("Reminder", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))
            HStack {
                Spacer()
                FlowTextButton(text: "Cancel", onClick: onDismiss)
                Button("Save") {
                    let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: selection)
                    onConfirm((components.hour ?? 0) * 60 + (components.minute ?? 0))
                }
                .font(FlowTypography.button)
                .foregroundStyle(colors.primary)
                .padding(.horizontal, FlowSpacers.x12)
            }
        }
        .padding(FlowSpacers.x16)
        .presentationDetents([.height(320)])
        .presentationBackground(colors.layer1)
    }
}
