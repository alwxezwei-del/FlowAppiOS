import SwiftUI

struct TaskEditorView: View {
    let taskId: String?

    @Environment(TaskService.self) private var taskService
    @Environment(Router.self) private var router
    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors

    @State private var draft: FlowTask?
    @State private var estimateMinutes: Int?
    @State private var showsDatePicker = false

    private static let estimatePresets = [15, 25, 45, 60]

    var body: some View {
        Screen(
            title: taskId == nil ? "New task" : "Edit task",
            onBack: { router.pop() },
            actions: taskId == nil ? nil : AnyView(TextButton(title: "Delete", isDestructive: true, action: delete))
        ) {
            if let draft = Binding($draft) {
                form(draft)
            }
        }
        .onAppear(perform: load)
    }

    private func form(_ task: Binding<FlowTask>) -> some View {
        let today = time.today
        let tomorrow = today.plusDays(1)
        let customDate = task.wrappedValue.dueDate.flatMap { $0 != today && $0 != tomorrow ? $0 : nil }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LabeledField(label: "Title", text: task.title, placeholder: "e.g. Finish Compose navigation")
                LabeledField(label: "Notes", text: task.description.orEmpty, placeholder: "Optional details", isMultiline: true)

                ChipGroup(title: "Category") {
                    FlowChip(title: "None", isSelected: task.wrappedValue.categoryId == nil) { task.wrappedValue.categoryId = nil }
                    ForEach(taskService.sortedCategories) { category in
                        FlowChip(title: category.name, isSelected: task.wrappedValue.categoryId == category.id, accent: colors.accent(category.color)) {
                            task.wrappedValue.categoryId = category.id
                        }
                    }
                }

                ChipGroup(title: "Priority") {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        FlowChip(title: priority.title, isSelected: task.wrappedValue.priority == priority) { task.wrappedValue.priority = priority }
                    }
                }

                ChipGroup(title: "Estimate") {
                    FlowChip(title: "No estimate", isSelected: estimateMinutes == nil) { estimateMinutes = nil }
                    ForEach(Self.estimatePresets, id: \.self) { minutes in
                        FlowChip(title: "\(minutes) min", isSelected: estimateMinutes == minutes) { estimateMinutes = minutes }
                    }
                }

                ChipGroup(title: "Due date") {
                    FlowChip(title: "No date", isSelected: task.wrappedValue.dueDate == nil) { task.wrappedValue.dueDate = nil }
                    FlowChip(title: "Today", isSelected: task.wrappedValue.dueDate == today) { task.wrappedValue.dueDate = today }
                    FlowChip(title: "Tomorrow", isSelected: task.wrappedValue.dueDate == tomorrow) { task.wrappedValue.dueDate = tomorrow }
                    FlowChip(title: customDate?.shortText ?? "Pick a date", isSelected: customDate != nil) { showsDatePicker = true }
                }

                PrimaryButton(title: "Save", isEnabled: !task.wrappedValue.title.trimmed.isEmpty, action: save)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsDatePicker) {
            DatePickerSheet(date: task.wrappedValue.dueDate ?? today) {
                task.wrappedValue.dueDate = $0
                showsDatePicker = false
            }
        }
    }

    private func load() {
        guard draft == nil else { return }
        // New tasks are due today so they show up on Home right away
        let task = taskService.task(id: taskId) ?? FlowTask(title: "", dueDate: time.today, createdAt: time.now())
        draft = task
        estimateMinutes = task.estimateSeconds.map { $0 / 60 }
    }

    private func save() {
        guard var task = draft else { return }
        task.title = task.title.trimmed
        task.description = task.description?.trimmed.nilIfEmpty
        task.estimateSeconds = estimateMinutes.map { $0 * 60 }
        if taskService.task(id: task.id) == nil {
            taskService.add(task)
        } else {
            taskService.update(task)
        }
        router.pop()
    }

    private func delete() {
        if let taskId { taskService.delete(taskId) }
        router.pop()
    }
}

private struct DatePickerSheet: View {
    let onSelect: (LocalDate) -> Void
    @State private var selection: Date

    @Environment(\.timeSource) private var time
    @Environment(\.colors) private var colors
    @Environment(\.dismiss) private var dismiss

    init(date: LocalDate, onSelect: @escaping (LocalDate) -> Void) {
        self.onSelect = onSelect
        _selection = State(initialValue: date.startOfDay(in: .current))
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Due date", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Spacer()
                TextButton(title: "Cancel") { dismiss() }
                Button("Select") { onSelect(time.day(of: selection)) }
                    .font(.flowButton)
                    .padding(.horizontal, 12)
            }
        }
        .padding(16)
        .presentationDetents([.medium, .large])
        .presentationBackground(colors.layer1)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Binding where Value == String? {
    /// Edits an optional string as a plain one, empty meaning `nil`.
    var orEmpty: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" }, set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
