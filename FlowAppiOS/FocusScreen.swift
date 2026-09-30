import SwiftUI

struct FocusScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @State private var selectedTaskID: UUID?
    @State private var selectedMinutes = 25
    @State private var remainingSeconds = 25 * 60
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            FlowTopBar(title: "Focus")
            ScrollView {
                VStack(spacing: 22) {
                    FlowSegmentedControl(items: [store.settings.focusMinutes, store.settings.shortBreakMinutes, store.settings.longBreakMinutes], selection: $selectedMinutes) { "\($0)m" }
                        .onChange(of: selectedMinutes) { _, newValue in if !isRunning { remainingSeconds = newValue * 60 } }
                    ProgressRing(progress: progress, stroke: 12) {
                        VStack(spacing: 8) {
                            Text(timeLabel).font(.system(size: 56, weight: .medium, design: .rounded)).foregroundStyle(flow.textMain)
                            Text(isRunning ? (isPaused ? "Paused" : "In focus") : "Ready")
                                .font(.system(size: 14)).foregroundStyle(flow.textSecondary)
                        }
                    }
                    .frame(width: 260, height: 260)
                    taskPicker
                    controls
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
        .onDisappear { timer?.invalidate() }
        .onAppear { selectedMinutes = store.settings.focusMinutes; remainingSeconds = store.settings.focusMinutes * 60 }
    }

    private var taskPicker: some View {
        FlowCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Linked task").font(.system(size: 14)).foregroundStyle(flow.textSecondary)
                Picker("Task", selection: $selectedTaskID) {
                    Text("Free focus session").tag(UUID?.none)
                    ForEach(store.tasks.filter { !$0.isCompleted }) { task in Text(task.title).tag(Optional(task.id)) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if isRunning {
                Button(isPaused ? "Resume" : "Pause") { togglePause() }.buttonStyle(PrimaryButtonStyle())
                Button("Stop") { stop(completed: false) }.font(.system(size: 16, weight: .semibold)).foregroundStyle(flow.error)
            } else {
                Button("Start focus") { start() }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var progress: Double { 1 - Double(remainingSeconds) / Double(max(selectedMinutes * 60, 1)) }
    private var timeLabel: String { String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60) }

    private func start() {
        isRunning = true; isPaused = false
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        guard isRunning, !isPaused else { return }
        if remainingSeconds > 0 { remainingSeconds -= 1 }
        if remainingSeconds == 0 { stop(completed: true) }
    }

    private func togglePause() { isPaused.toggle() }

    private func stop(completed: Bool) {
        timer?.invalidate(); timer = nil
        let actual = max(1, selectedMinutes - Int(ceil(Double(remainingSeconds) / 60)))
        store.saveFocusSession(taskID: selectedTaskID, planned: selectedMinutes, actual: completed ? selectedMinutes : actual, completed: completed)
        isRunning = false; isPaused = false; remainingSeconds = selectedMinutes * 60
    }
}
