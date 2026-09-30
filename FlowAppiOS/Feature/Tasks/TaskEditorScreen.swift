import SwiftUI
import Observation

struct CategoryOptionUi: Identifiable, Hashable {
    let id: String
    let name: String
    let color: AccentColor
}

/** Task editor state */
struct TaskEditorUiState {
    var isEditing = false
    var title = ""
    var description = ""
    var categoryId: String?
    var priority: Priority = .default
    var estimateMinutes: Int?
    var dueDate: LocalDate?
    var categories: [CategoryOptionUi] = []

    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@MainActor
@Observable
final class TaskEditorViewModel {
    var state: TaskEditorUiState

    @ObservationIgnored private let container: AppContainer
    @ObservationIgnored private let taskId: String?

    init(container: AppContainer, taskId: String?) {
        self.container = container
        self.taskId = taskId

        let database = container.database
        let task = database.task(id: taskId)
        state = TaskEditorUiState(
            isEditing: taskId != nil,
            title: task?.title ?? "",
            description: task?.description ?? "",
            categoryId: task?.categoryId,
            priority: task?.priority ?? .default,
            estimateMinutes: task?.estimateSeconds.map { $0 / 60 },
            // New tasks default to today so they show up on Today right away
            dueDate: task?.dueDate ?? (taskId == nil ? container.timeProvider.today() : nil),
            categories: database.sortedCategories.map { CategoryOptionUi(id: $0.id, name: $0.name, color: $0.color) }
        )
    }

    /** - Returns: true when the screen should close */
    func save() -> Bool {
        guard state.canSave else { return false }
        let database = container.database
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = state.description.trimmingCharacters(in: .whitespacesAndNewlines)

        if var task = database.task(id: taskId) {
            task.title = title
            task.description = description.isEmpty ? nil : description
            task.categoryId = state.categoryId
            task.estimateSeconds = state.estimateMinutes.map { $0 * 60 }
            task.dueDate = state.dueDate
            task.priority = state.priority
            database.updateTask(task)
        } else {
            database.createTask(FlowTask(
                title: title,
                description: description.isEmpty ? nil : description,
                categoryId: state.categoryId,
                estimateSeconds: state.estimateMinutes.map { $0 * 60 },
                dueDate: state.dueDate,
                priority: state.priority,
                createdAt: container.timeProvider.now()
            ))
        }
        return true
    }

    func delete() {
        guard let taskId else { return }
        container.database.deleteTask(id: taskId)
    }
}

/**
 * Create/edit task screen
 */
struct TaskEditorScreen: View {
    private let router: AppRouter
    /** used for due date presets */
    private let today: LocalDate
    @State private var viewModel: TaskEditorViewModel
    @State private var datePickerVisible = false

    @Environment(\.flowColors) private var colors

    init(container: AppContainer, taskId: String?) {
        router = container.router
        today = container.timeProvider.today()
        _viewModel = State(initialValue: TaskEditorViewModel(container: container, taskId: taskId))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let state = viewModel.state
        let tomorrow = today.plusDays(1)

        FlowScaffold(topBar: {
            FlowTopBar(title: state.isEditing ? "Edit task" : "New task", onBack: router.navigateUp) {
                if state.isEditing {
                    FlowTextButton(text: "Delete", destructive: true) {
                        viewModel.delete()
                        router.navigateUp()
                    }
                }
            }
        }) {
            ScrollView {
                VStack(alignment: .leading, spacing: FlowSpacers.x20) {
                    FlowTextField(label: "Title", text: $viewModel.state.title, placeholder: "e.g. Finish Compose navigation")

                    FlowTextField(label: "Notes", text: $viewModel.state.description, placeholder: "Optional details", singleLine: false, minLines: 3)

                    EditorSection(title: "Category") {
                        FlowChip(text: "None", selected: state.categoryId == nil) { viewModel.state.categoryId = nil }
                        ForEach(state.categories) { category in
                            FlowChip(text: category.name, selected: state.categoryId == category.id, accent: colors.accent(category.color)) {
                                viewModel.state.categoryId = category.id
                            }
                        }
                    }

                    EditorSection(title: "Priority") {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            FlowChip(text: priority.label, selected: state.priority == priority) { viewModel.state.priority = priority }
                        }
                    }

                    EditorSection(title: "Estimate") {
                        FlowChip(text: "No estimate", selected: state.estimateMinutes == nil) { viewModel.state.estimateMinutes = nil }
                        ForEach(Self.estimatePresets, id: \.self) { minutes in
                            FlowChip(text: "\(minutes) min", selected: state.estimateMinutes == minutes) { viewModel.state.estimateMinutes = minutes }
                        }
                    }

                    EditorSection(title: "Due date") {
                        FlowChip(text: "No date", selected: state.dueDate == nil) { viewModel.state.dueDate = nil }
                        FlowChip(text: "Today", selected: state.dueDate == today) { viewModel.state.dueDate = today }
                        FlowChip(text: "Tomorrow", selected: state.dueDate == tomorrow) { viewModel.state.dueDate = tomorrow }
                        let custom = state.dueDate.flatMap { $0 != today && $0 != tomorrow ? $0 : nil }
                        FlowChip(text: custom?.formatShortDate() ?? "Pick a date", selected: custom != nil) { datePickerVisible = true }
                    }

                    FlowPrimaryButton(text: "Save", enabled: state.canSave) {
                        if viewModel.save() { router.navigateUp() }
                    }
                }
                .padding(.horizontal, FlowSpacers.x16)
                .padding(.vertical, FlowSpacers.x8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $datePickerVisible) {
            DueDatePickerSheet(initialDate: state.dueDate ?? today) { date in
                viewModel.state.dueDate = date
                datePickerVisible = false
            } onDismiss: {
                datePickerVisible = false
            }
        }
    }

    /** Estimate presets, same as timer presets */
    private static let estimatePresets = [15, 25, 45, 60]
}

extension Priority {
    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    @Environment(\.flowColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: FlowSpacers.x8) {
            if !title.isEmpty {
                Text(title).font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FlowSpacers.x8, content: content)
            }
            .scrollClipDisabled()
        }
    }
}

private struct DueDatePickerSheet: View {
    let onSelect: (LocalDate) -> Void
    let onDismiss: () -> Void
    @State private var selection: Date

    @Environment(\.flowColors) private var colors
    private let calendar = SystemTimeProvider().calendar

    init(initialDate: LocalDate, onSelect: @escaping (LocalDate) -> Void, onDismiss: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        _selection = State(initialValue: initialDate.startOfDay(in: SystemTimeProvider().calendar))
    }

    var body: some View {
        VStack(spacing: FlowSpacers.x8) {
            DatePicker("Due date", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
            HStack {
                Spacer()
                FlowTextButton(text: "Cancel", onClick: onDismiss)
                Button("Select") { onSelect(LocalDate.from(selection, calendar: calendar)) }
                    .font(FlowTypography.button)
                    .foregroundStyle(colors.primary)
                    .padding(.horizontal, FlowSpacers.x12)
            }
        }
        .padding(FlowSpacers.x16)
        .presentationDetents([.medium, .large])
        .presentationBackground(colors.layer1)
    }
}
