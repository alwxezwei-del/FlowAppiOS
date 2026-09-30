import SwiftUI

struct HabitEditorView: View {
    let habitId: String?

    @Environment(HabitService.self) private var habitService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    @State private var draft: Habit?
    @State private var isDaily = true
    @State private var days = Set(DayOfWeek.allCases)
    @State private var showsTimePicker = false

    private static let defaultReminder = 19 * 60

    var body: some View {
        Screen(
            title: habitId == nil ? "New habit" : "Edit habit",
            onBack: { router.pop() },
            actions: habitId == nil ? nil : AnyView(TextButton(title: "Delete", isDestructive: true, action: delete))
        ) {
            if let draft = Binding($draft) {
                form(draft)
            }
        }
        .onAppear(perform: load)
    }

    private func form(_ habit: Binding<Habit>) -> some View {
        let color = habit.wrappedValue.color

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ChipGroup(title: "Icon") {
                    ForEach(IconKey.all, id: \.self) { icon in
                        let isSelected = habit.wrappedValue.icon == icon
                        Button { habit.wrappedValue.icon = icon } label: {
                            IconBadge(icon: icon, accent: color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? colors.accent(color) : colors.divider, lineWidth: isSelected ? 2 : 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(icon)
                    }
                }

                LabeledField(label: "Name", text: habit.name, placeholder: "e.g. Read")

                ChipGroup(title: "Color") {
                    ForEach(AccentColor.allCases, id: \.self) { accent in
                        ColorDot(color: colors.accent(accent), isSelected: color == accent) { habit.wrappedValue.color = accent }
                    }
                }

                ChipGroup(title: "Schedule") {
                    FlowChip(title: "Every day", isSelected: isDaily) { isDaily = true }
                    FlowChip(title: "Selected days", isSelected: !isDaily) { isDaily = false }
                }

                if !isDaily {
                    ChipGroup {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            FlowChip(title: day.shortName.uppercased(), isSelected: days.contains(day)) {
                                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                            }
                        }
                    }
                }

                target(habit.targetPerDay)
                reminder(habit.reminderMinuteOfDay)

                LabeledField(label: "Notes (optional)", text: habit.note.orEmpty, placeholder: "e.g. Work on personal project", isMultiline: true)

                PrimaryButton(title: "Save", isEnabled: canSave(habit.wrappedValue), action: save)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsTimePicker) {
            TimePickerSheet(minuteOfDay: habit.wrappedValue.reminderMinuteOfDay ?? Self.defaultReminder) {
                habit.wrappedValue.reminderMinuteOfDay = $0
                showsTimePicker = false
            }
        }
    }

    private func target(_ value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target").font(.flowBody2).foregroundStyle(colors.textSecondary)
            HStack(spacing: 12) {
                IconButton(systemName: "minus", label: "Decrease target") { value.wrappedValue = max(value.wrappedValue - 1, 1) }
                Text("\(value.wrappedValue)").font(.flowTitle2).foregroundStyle(colors.textMain)
                IconButton(systemName: "plus", label: "Increase target") { value.wrappedValue = min(value.wrappedValue + 1, 20) }
                Text("time(s) per day").font(.flowBody2).foregroundStyle(colors.textSecondary)
            }
        }
    }

    private func reminder(_ minute: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder (optional)").font(.flowBody2).foregroundStyle(colors.textSecondary)
            HStack {
                if let value = minute.wrappedValue {
                    FlowChip(title: timeText(minuteOfDay: value), isSelected: true) { showsTimePicker = true }
                }
                Spacer()
                Toggle("Reminder", isOn: Binding(
                    get: { minute.wrappedValue != nil },
                    set: { minute.wrappedValue = $0 ? Self.defaultReminder : nil }
                ))
                .labelsHidden()
            }
        }
    }

    private func canSave(_ habit: Habit) -> Bool {
        !habit.name.trimmed.isEmpty && (isDaily || !days.isEmpty)
    }

    private func load() {
        guard draft == nil else { return }
        let habit = habitService.habit(id: habitId) ?? Habit(name: "", icon: IconKey.fallback, createdAt: time.now())
        draft = habit
        if case .selectedDays(let selected) = habit.schedule {
            isDaily = false
            days = selected
        }
    }

    private func save() {
        guard var habit = draft else { return }
        habit.name = habit.name.trimmed
        habit.note = habit.note?.trimmed.nilIfEmpty
        habit.schedule = isDaily ? .daily : .selectedDays(days)
        if habitService.habit(id: habit.id) == nil {
            habitService.add(habit)
        } else {
            habitService.update(habit)
        }
        router.pop()
    }

    private func delete() {
        if let habitId { habitService.delete(habitId) }
        // Skip the details screen of the habit that no longer exists
        router.pop(2)
    }
}

private struct TimePickerSheet: View {
    let onSelect: (Int) -> Void
    @State private var selection: Date

    @Environment(\.colors) private var colors
    @Environment(\.dismiss) private var dismiss

    init(minuteOfDay: Int, onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
        _selection = State(initialValue: Calendar.current.date(from: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60)) ?? .now)
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Reminder", selection: $selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))
            HStack {
                Spacer()
                TextButton(title: "Cancel") { dismiss() }
                Button("Save") {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: selection)
                    onSelect((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
                }
                .font(.flowButton)
                .padding(.horizontal, 12)
            }
        }
        .padding(16)
        .presentationDetents([.height(320)])
        .presentationBackground(colors.layer1)
    }
}
