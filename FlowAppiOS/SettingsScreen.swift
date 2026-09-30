import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: FlowStore
    @Environment(\.flow) private var flow
    @Environment(\.dismiss) private var dismiss
    @State private var resetDialog = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                FlowTopBar(title: "Settings", back: { dismiss() }).padding(.horizontal, -16)
                SectionHeader(title: "Timer")
                FlowCard { timerSettings }
                SectionHeader(title: "Appearance")
                FlowCard { appearanceSettings }
                SectionHeader(title: "Data")
                FlowCard { dataSettings }
                FlowCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FlowApp").font(.system(size: 16)).foregroundStyle(flow.textMain)
                        Text("Version 1.0.0").font(.system(size: 13)).foregroundStyle(flow.textSecondary)
                        Text("Offline-first productivity app for tasks, habits and focus sessions.").font(.system(size: 13)).foregroundStyle(flow.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(flow.layer0.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Reset data?", isPresented: $resetDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { store.resetAllData() }
        } message: { Text("This deletes all local FlowApp data on this simulator.") }
    }

    private var timerSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Stepper("Focus duration: \(store.settings.focusMinutes)m", value: $store.settings.focusMinutes, in: 5...90, step: 5)
            Stepper("Short break: \(store.settings.shortBreakMinutes)m", value: $store.settings.shortBreakMinutes, in: 1...30, step: 1)
            Stepper("Long break: \(store.settings.longBreakMinutes)m", value: $store.settings.longBreakMinutes, in: 5...60, step: 5)
        }.font(.system(size: 15)).foregroundStyle(flow.textMain)
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Theme", selection: $store.settings.themeMode) { ForEach(ThemeMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Text("Accent").font(.system(size: 14)).foregroundStyle(flow.textSecondary)
            HStack(spacing: 10) {
                ForEach(AccentColor.allCases) { accent in
                    Button { store.settings.accentColor = accent } label: {
                        Circle()
                            .fill(accent.color(for: flow.isDark ? .dark : .light))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(store.settings.accentColor == accent ? flow.textMain : Color.clear, lineWidth: 3))
                    }.buttonStyle(.plain)
                }
            }
            Toggle("Notifications", isOn: $store.settings.notificationsEnabled)
        }.font(.system(size: 15)).foregroundStyle(flow.textMain)
    }

    private var dataSettings: some View {
        VStack(spacing: 4) {
            ButtonRow(title: "Export backup", subtitle: "Coming from Android concept: local JSON backup", destructive: false) {}
            ButtonRow(title: "Import backup", subtitle: "Ready for future file importer", destructive: false) {}
            ButtonRow(title: "Reset all data", subtitle: "Delete local tasks, habits and focus sessions", destructive: true) { resetDialog = true }
        }
    }
}

struct ButtonRow: View {
    @Environment(\.flow) private var flow
    var title: String
    var subtitle: String
    var destructive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16)).foregroundStyle(destructive ? flow.error : flow.textMain)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(flow.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
        }.buttonStyle(.plain)
    }
}
