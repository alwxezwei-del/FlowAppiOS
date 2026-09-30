import SwiftUI

enum TaskFilter: String, CaseIterable, Hashable { case all = "All", today = "Today", upcoming = "Upcoming", completed = "Completed" }

struct TasksScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @Binding var selectedTab: FlowTab
    @State private var filter: TaskFilter = .all
    @State private var editingTask: FlowTask?
    @State private var createPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                FlowTopBar(title: "Tasks", actions: [TopBarAction(icon: "plus", action: { createPresented = true })])
                    .padding(.horizontal, -16)
                FlowSegmentedControl(items: TaskFilter.allCases, selection: $filter) { $0.rawValue }
                FlowCard(padding: 12) {
                    if filteredTasks.isEmpty {
                        EmptyState(icon: "tray", title: "No tasks here", subtitle: "Your filtered list is empty.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredTasks) { task in
                                TaskRowView(task: task, category: store.category(for: task.categoryID), onToggle: { store.toggleTask(task, completed: $0) }, onTap: { editingTask = task })
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) { store.deleteTask(task) } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $editingTask) { TaskEditorScreen(task: $0) }
        .sheet(isPresented: $createPresented) { TaskEditorScreen(task: nil) }
    }

    private var filteredTasks: [FlowTask] {
        store.tasks.filter { task in
            switch filter {
            case .all: true
            case .today: task.dueDate.map { Calendar.current.isDateInToday($0) } ?? false
            case .upcoming: (task.dueDate ?? .distantPast) > Date() && !task.isCompleted
            case .completed: task.isCompleted
            }
        }
    }
}

struct TaskEditorScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.flow) private var flow
    @State private var draft: FlowTask

    init(task: FlowTask?) {
        _draft = State(initialValue: task ?? FlowTask(title: "", notes: "", categoryID: nil, estimateMinutes: 25, focusedMinutes: 0, dueDate: Date(), priority: .normal, status: .active, createdAt: Date()))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draft.title)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                    Picker("Category", selection: $draft.categoryID) {
                        Text("Inbox").tag(UUID?.none)
                        ForEach(store.categories) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Priority", selection: $draft.priority) { ForEach(TaskPriority.allCases) { Text($0.title).tag($0) } }
                    Stepper("Estimate: \(draft.estimateMinutes)m", value: $draft.estimateMinutes, in: 5...180, step: 5)
                    DatePicker("Due", selection: Binding(get: { draft.dueDate ?? Date() }, set: { draft.dueDate = $0 }), displayedComponents: .date)
                }
            }
            .navigationTitle(draft.title.isEmpty ? "New task" : "Edit task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { store.saveTask(draft); dismiss() }.disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .scrollContentBackground(.hidden)
            .background(flow.layer0)
        }
    }
}
