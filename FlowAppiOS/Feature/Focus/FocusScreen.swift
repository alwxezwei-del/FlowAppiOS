import SwiftUI
import Observation

struct FocusPresetUi: Hashable {
    let kind: FocusKind
    let minutes: Int

    var label: String {
        switch kind {
        case .focus: "\(minutes) min"
        case .shortBreak: "Break \(minutes)m"
        case .longBreak: "Long \(minutes)m"
        }
    }
}

/**
 * Task in the picker
 */
struct FocusTaskUi: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
}

/**
 * Timer screen state
 */
struct FocusUiState {
    var isRunning = false
    var isPaused = false
    var timeLabel = ""
    var progress: Double = 0
    var kind: FocusKind = .focus
    var selectedTaskId: String?
    var selectedTaskTitle: String?
    var tasks: [FocusTaskUi] = []
    var presets: [FocusPresetUi] = []
    var selectedMinutes = 0

    var isActive: Bool { isRunning || isPaused }
}

extension FocusKind {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }
}

/**
 * Timer screen ViewModel. Remaining time isn't stored: each tick recomputes it from controller
 * state and the clock.
 */
@MainActor
@Observable
final class FocusViewModel {
    var taskPickerVisible = false
    var durationPickerVisible = false

    private var selectedTaskId: String?
    private var selectedMinutes: Int?
    private var selectedKind: FocusKind = .focus

    @ObservationIgnored private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func state(at now: Date) -> FocusUiState {
        let timerState = container.timerController.state
        let settings = container.settingsStore.settings
        let presets = [
            FocusPresetUi(kind: .focus, minutes: settings.focusMinutes),
            FocusPresetUi(kind: .shortBreak, minutes: settings.shortBreakMinutes),
            FocusPresetUi(kind: .longBreak, minutes: settings.longBreakMinutes),
        ]
        let tasks = activeTasks()
        let session = timerState.runningSession

        // While a session is active, show its params instead of the picker selection
        let kind = session?.kind ?? selectedKind
        let minutes = session.map { $0.plannedSeconds / 60 }
            ?? selectedMinutes
            ?? presets.first { $0.kind == kind }?.minutes
            ?? settings.focusMinutes
        let taskId = session?.taskId ?? selectedTaskId

        return FocusUiState(
            isRunning: timerState.isRunning,
            isPaused: timerState.isPaused,
            timeLabel: session != nil ? timerState.remaining(at: now).formatTimer() : TimeInterval(minutes * 60).formatTimer(),
            progress: timerState.progress(at: now),
            kind: kind,
            selectedTaskId: taskId,
            selectedTaskTitle: session?.taskTitle ?? tasks.first { $0.id == taskId }?.title,
            tasks: tasks,
            presets: presets,
            selectedMinutes: minutes
        )
    }

    func consumePendingTask() {
        guard let taskId = container.router.pendingFocusTaskId else { return }
        container.router.pendingFocusTaskId = nil
        if container.timerController.state == .idle { selectedTaskId = taskId }
    }

    func selectPreset(_ preset: FocusPresetUi) {
        selectedKind = preset.kind
        selectedMinutes = preset.minutes
    }

    func selectCustomDuration(_ minutes: Int) {
        selectedKind = .focus
        selectedMinutes = min(max(minutes, Self.minMinutes), Self.maxMinutes)
        durationPickerVisible = false
    }

    func selectTask(_ taskId: String?) {
        selectedTaskId = taskId
        taskPickerVisible = false
    }

    func start() {
        let current = state(at: container.timeProvider.now())
        let task = container.database.task(id: current.selectedTaskId)
        container.timerController.start(RunningSession(
            taskId: task?.id,
            taskTitle: task?.title,
            categoryId: task?.categoryId,
            // Breaks aren't counted towards a task, so a session with a task is always focus
            kind: task != nil ? .focus : current.kind,
            plannedSeconds: current.selectedMinutes * 60,
            startedAt: container.timeProvider.now()
        ))
    }

    func togglePause() {
        switch container.timerController.state {
        case .running: container.timerController.pause()
        case .paused: container.timerController.resume()
        case .idle: break
        }
    }

    func stop() {
        container.timerController.stop(completed: false)
    }

    func requestNotificationPermission() {
        container.notifications.requestPermission()
    }

    private func activeTasks() -> [FocusTaskUi] {
        let database = container.database
        return database.allTasks
            .filter { $0.status == .active }
            .map { task in
                let parts = [database.category(id: task.categoryId)?.name, task.estimateSeconds?.formatShort()].compactMap { $0 }
                return FocusTaskUi(id: task.id, title: task.title, subtitle: parts.isEmpty ? nil : parts.joined(separator: " · "))
            }
    }

    private static let minMinutes = 1
    private static let maxMinutes = 180
}

/** Focus screen.*/
struct FocusScreen: View {
    private let router: AppRouter
    @State private var viewModel: FocusViewModel

    @Environment(\.flowColors) private var colors

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: FocusViewModel(container: container))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        FlowScaffold {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(state: viewModel.state(at: context.date))
            }
        }
        .onAppear {
            viewModel.requestNotificationPermission()
            viewModel.consumePendingTask()
        }
        .onChange(of: router.pendingFocusTaskId) { viewModel.consumePendingTask() }
        .sheet(isPresented: $viewModel.taskPickerVisible) {
            let state = viewModel.state(at: .now)
            TaskPickerSheet(tasks: state.tasks, selectedTaskId: state.selectedTaskId, onSelect: viewModel.selectTask)
        }
        .sheet(isPresented: $viewModel.durationPickerVisible) {
            CustomDurationSheet(initialMinutes: viewModel.state(at: .now).selectedMinutes, onConfirm: viewModel.selectCustomDuration) {
                viewModel.durationPickerVisible = false
            }
        }
    }

    private func content(state: FocusUiState) -> some View {
        GeometryReader { proxy in
            ScrollView {
                column(state: state).frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func column(state: FocusUiState) -> some View {
        VStack(spacing: FlowSpacers.x24) {
            VStack(spacing: FlowSpacers.x4) {
                Text(state.kind.title)
                    .font(FlowTypography.title1)
                    .foregroundStyle(colors.textMain)
                Text("Stay in the zone")
                    .font(FlowTypography.body2)
                    .foregroundStyle(colors.textSecondary)
            }

            FlowProgressRing(progress: state.progress, strokeWidth: 12) {
                VStack(spacing: FlowSpacers.x4) {
                    Text(state.timeLabel)
                        .font(FlowTypography.timer)
                        .foregroundStyle(colors.textMain)
                        .contentTransition(.numericText())
                    Text(state.selectedTaskTitle ?? "Free session")
                        .font(FlowTypography.body2)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, FlowSpacers.x24)
                }
            }
            .frame(width: 260, height: 260)

            if !state.isActive {
                ViewThatFits(in: .horizontal) {
                    presets(state: state)
                    ScrollView(.horizontal, showsIndicators: false) { presets(state: state) }
                }

                FlowSecondaryButton(text: state.selectedTaskTitle ?? "Choose a task") { viewModel.taskPickerVisible = true }

                FlowPrimaryButton(text: "Start") { viewModel.start() }
            } else {
                FlowPrimaryButton(text: state.isPaused ? "Resume" : "Pause") { viewModel.togglePause() }

                FlowTextButton(text: "End session") { viewModel.stop() }
            }
        }
        .padding(.horizontal, FlowSpacers.x24)
        .padding(.vertical, FlowSpacers.x24)
        .frame(maxWidth: .infinity)
    }

    private func presets(state: FocusUiState) -> some View {
        HStack(spacing: FlowSpacers.x8) {
            ForEach(state.presets, id: \.self) { preset in
                FlowChip(text: preset.label, selected: state.kind == preset.kind && state.selectedMinutes == preset.minutes) {
                    viewModel.selectPreset(preset)
                }
            }
            FlowChip(text: "Custom", selected: !state.presets.contains { $0.minutes == state.selectedMinutes }) {
                viewModel.durationPickerVisible = true
            }
        }
    }
}

/**
 * Task picker for a session
 */
private struct TaskPickerSheet: View {
    let tasks: [FocusTaskUi]
    let selectedTaskId: String?
    let onSelect: (String?) -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Choose a task")
                    .font(FlowTypography.title2)
                    .foregroundStyle(colors.textMain)
                    .padding(.vertical, FlowSpacers.x12)

                PickerRow(title: "No task", subtitle: nil, selected: selectedTaskId == nil) { onSelect(nil) }

                if tasks.isEmpty {
                    EmptyState(title: "No active tasks. You can still run a free session.")
                }

                ForEach(tasks) { task in
                    PickerRow(title: task.title, subtitle: task.subtitle, selected: task.id == selectedTaskId) { onSelect(task.id) }
                }
            }
            .padding(.horizontal, FlowSpacers.x16)
            .padding(.top, FlowSpacers.x8)
            .padding(.bottom, FlowSpacers.x24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(colors.layer1)
    }
}

private struct PickerRow: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: FlowSpacers.x12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(FlowTypography.body1).foregroundStyle(colors.textMain)
                    if let subtitle {
                        Text(subtitle).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    Image(systemName: "checkmark").foregroundStyle(colors.primary)
                }
            }
            .padding(.vertical, FlowSpacers.x12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/** Custom interval duration dialog */
private struct CustomDurationSheet: View {
    let onConfirm: (Int) -> Void
    let onDismiss: () -> Void
    @State private var text: String

    @Environment(\.flowColors) private var colors

    init(initialMinutes: Int, onConfirm: @escaping (Int) -> Void, onDismiss: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _text = State(initialValue: String(initialMinutes))
    }

    var body: some View {
        let minutes = Int(text)
        VStack(alignment: .leading, spacing: FlowSpacers.x16) {
            Text("Custom duration")
                .font(FlowTypography.title2)
                .foregroundStyle(colors.textMain)
            FlowTextField(label: "Minutes", text: $text, keyboardType: .numberPad)
                .onChange(of: text) { _, input in
                    let filtered = String(input.filter(\.isNumber).prefix(3))
                    if filtered != input { text = filtered }
                }
            HStack {
                Spacer()
                FlowTextButton(text: "Cancel", onClick: onDismiss)
                Button("Set") { minutes.map(onConfirm) }
                    .font(FlowTypography.button)
                    .foregroundStyle((minutes ?? 0) > 0 ? colors.primary : colors.textTertiary)
                    .disabled((minutes ?? 0) <= 0)
                    .padding(.horizontal, FlowSpacers.x12)
            }
        }
        .padding(FlowSpacers.x24)
        .presentationDetents([.height(250)])
        .presentationBackground(colors.layer1)
    }
}
