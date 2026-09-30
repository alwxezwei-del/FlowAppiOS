import SwiftUI

struct FocusView: View {
    private struct Preset: Hashable {
        let kind: FocusKind
        let minutes: Int

        var title: String {
            switch kind {
            case .focus: "\(minutes) min"
            case .shortBreak: "Break \(minutes)m"
            case .longBreak: "Long \(minutes)m"
            }
        }
    }

    @Environment(FocusService.self) private var focusService
    @Environment(TaskService.self) private var taskService
    @Environment(SettingsService.self) private var settingsService
    @Environment(Router.self) private var router
    @Environment(\.colors) private var colors

    @State private var kind = FocusKind.focus
    @State private var customMinutes: Int?
    @State private var taskId: String?
    @State private var showsTaskPicker = false
    @State private var showsDurationPicker = false

    var body: some View {
        Screen {
            // The view re-renders every second while the timer is on screen
            TimelineView(.periodic(from: .now, by: 1)) { context in
                GeometryReader { proxy in
                    ScrollView {
                        content(now: context.date).frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .onAppear {
            focusService.requestNotificationPermission()
            takeTaskFromRouter()
        }
        .onChange(of: router.focusTaskId) { takeTaskFromRouter() }
        .sheet(isPresented: $showsTaskPicker) {
            TaskPickerSheet(tasks: activeTasks, selectedId: taskId) {
                taskId = $0
                showsTaskPicker = false
            }
        }
        .sheet(isPresented: $showsDurationPicker) {
            DurationSheet(minutes: selectedMinutes) {
                kind = .focus
                customMinutes = min(max($0, 1), 180)
                showsDurationPicker = false
            }
        }
    }

    private func content(now: Date) -> some View {
        let active = focusService.active
        let title = active?.taskTitle ?? taskService.task(id: taskId)?.title

        return VStack(spacing: 24) {
            VStack(spacing: 4) {
                Text((active?.kind ?? kind).title).font(.flowTitle1).foregroundStyle(colors.textMain)
                Text("Stay in the zone").font(.flowBody2).foregroundStyle(colors.textSecondary)
            }

            ProgressRing(value: active?.progress(at: now) ?? 0) {
                VStack(spacing: 4) {
                    Text(active?.remaining(at: now).timerText ?? TimeInterval(selectedMinutes * 60).timerText)
                        .font(.flowTimer)
                        .foregroundStyle(colors.textMain)
                        .contentTransition(.numericText())
                    Text(title ?? "Free session")
                        .font(.flowBody2)
                        .foregroundStyle(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
            }
            .frame(width: 260, height: 260)

            if let active {
                PrimaryButton(title: active.isRunning ? "Pause" : "Resume") { focusService.togglePause() }
                TextButton(title: "End session") { focusService.stop() }
            } else {
                ViewThatFits(in: .horizontal) {
                    presetChips
                    ScrollView(.horizontal, showsIndicators: false) { presetChips }
                }
                SecondaryButton(title: title ?? "Choose a task") { showsTaskPicker = true }
                PrimaryButton(title: "Start") {
                    focusService.start(task: taskService.task(id: taskId), kind: kind, minutes: selectedMinutes)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var presetChips: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { preset in
                FlowChip(title: preset.title, isSelected: kind == preset.kind && selectedMinutes == preset.minutes) {
                    kind = preset.kind
                    customMinutes = preset.minutes
                }
            }
            FlowChip(title: "Custom", isSelected: !presets.contains { $0.minutes == selectedMinutes }) { showsDurationPicker = true }
        }
    }

    private var presets: [Preset] {
        let settings = settingsService.settings
        return [
            Preset(kind: .focus, minutes: settings.focusMinutes),
            Preset(kind: .shortBreak, minutes: settings.shortBreakMinutes),
            Preset(kind: .longBreak, minutes: settings.longBreakMinutes),
        ]
    }

    private var selectedMinutes: Int {
        customMinutes ?? presets.first { $0.kind == kind }?.minutes ?? 25
    }

    private var activeTasks: [FlowTask] {
        taskService.allTasks.filter { $0.status == .active }
    }

    private func takeTaskFromRouter() {
        guard let id = router.focusTaskId else { return }
        router.focusTaskId = nil
        if focusService.active == nil { taskId = id }
    }
}

private struct TaskPickerSheet: View {
    let tasks: [FlowTask]
    let selectedId: String?
    let onSelect: (String?) -> Void

    @Environment(TaskService.self) private var taskService
    @Environment(\.colors) private var colors

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Choose a task").font(.flowTitle2).foregroundStyle(colors.textMain).padding(.vertical, 12)
                row("No task", subtitle: nil, isSelected: selectedId == nil) { onSelect(nil) }
                if tasks.isEmpty {
                    EmptyState(title: "No active tasks. You can still run a free session.")
                }
                ForEach(tasks) { task in
                    let subtitle = [taskService.category(id: task.categoryId)?.name, task.estimateSeconds?.durationText].dotted
                    row(task.title, subtitle: subtitle, isSelected: task.id == selectedId) { onSelect(task.id) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(colors.layer1)
    }

    private func row(_ title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.flowBody1).foregroundStyle(colors.textMain)
                    if let subtitle {
                        Text(subtitle).font(.flowCaption).foregroundStyle(colors.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(colors.primary)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DurationSheet: View {
    let onSet: (Int) -> Void
    @State private var text: String

    @Environment(\.colors) private var colors
    @Environment(\.dismiss) private var dismiss

    init(minutes: Int, onSet: @escaping (Int) -> Void) {
        self.onSet = onSet
        _text = State(initialValue: String(minutes))
    }

    var body: some View {
        let minutes = Int(text) ?? 0
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom duration").font(.flowTitle2).foregroundStyle(colors.textMain)
            LabeledField(label: "Minutes", text: $text, keyboard: .numberPad)
                .onChange(of: text) { _, value in
                    let digits = String(value.filter(\.isNumber).prefix(3))
                    if digits != value { text = digits }
                }
            HStack {
                Spacer()
                TextButton(title: "Cancel") { dismiss() }
                Button("Set") { onSet(minutes) }
                    .font(.flowButton)
                    .disabled(minutes <= 0)
                    .padding(.horizontal, 12)
            }
        }
        .padding(24)
        .presentationDetents([.height(250)])
        .presentationBackground(colors.layer1)
    }
}
