import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(SettingsService.self) private var settingsService
    @Environment(BackupService.self) private var backupService
    @Environment(Router.self) private var router
    @Environment(\.colors) private var colors

    @State private var exportFile: BackupFile?
    @State private var showsImporter = false
    @State private var showsResetAlert = false
    @State private var message: String?

    var body: some View {
        let settings = settingsService.settings

        Screen(title: "Settings", onBack: { router.pop() }) {
            ScrollContent {
                SectionHeader(title: "Timer")
                FlowCard {
                    VStack(alignment: .leading, spacing: 16) {
                        options("Focus duration", [15, 25, 45, 60], selected: settings.focusMinutes, title: { "\($0) min" }) { value in
                            settingsService.update { $0.focusMinutes = value }
                        }
                        options("Short break", [3, 5, 10], selected: settings.shortBreakMinutes, title: { "\($0) min" }) { value in
                            settingsService.update { $0.shortBreakMinutes = value }
                        }
                        options("Long break", [10, 15, 20, 30], selected: settings.longBreakMinutes, title: { "\($0) min" }) { value in
                            settingsService.update { $0.longBreakMinutes = value }
                        }
                    }
                }

                SectionHeader(title: "Appearance")
                FlowCard {
                    VStack(alignment: .leading, spacing: 16) {
                        options("Theme", ThemeMode.allCases, selected: settings.themeMode, title: \.rawValue.capitalized) { value in
                            settingsService.update { $0.themeMode = value }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accent color").font(.flowBody2).foregroundStyle(colors.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(AccentColor.allCases, id: \.self) { accent in
                                    ColorDot(color: colors.accent(accent), isSelected: accent == settings.accentColor, size: 32) {
                                        settingsService.update { $0.accentColor = accent }
                                    }
                                }
                            }
                        }
                        options("Start of week", [DayOfWeek.monday, .sunday], selected: settings.startOfWeek, title: \.name) { value in
                            settingsService.update { $0.startOfWeek = value }
                        }
                        Toggle(isOn: Binding(get: { settings.notificationsEnabled }, set: { value in settingsService.update { $0.notificationsEnabled = value } })) {
                            VStack(alignment: .leading) {
                                Text("Notifications").font(.flowBody1).foregroundStyle(colors.textMain)
                                Text("Timer notification and habit reminders").font(.flowCaption).foregroundStyle(colors.textSecondary)
                            }
                        }
                    }
                }

                SectionHeader(title: "Data")
                FlowCard {
                    VStack(spacing: 4) {
                        action("Export data", "Save everything as a JSON file", perform: export)
                        action("Import data", "Restore from a JSON file") { showsImporter = true }
                        action("Reset application", "Delete all tasks, habits and sessions", isDestructive: true) { showsResetAlert = true }
                    }
                }

                FlowCard {
                    Text("FlowApp").font(.flowBody1).foregroundStyle(colors.textMain)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.flowCaption)
                        .foregroundStyle(colors.textSecondary)
                    Text("All data stays on this device. No account, no backend, no network.")
                        .font(.flowCaption)
                        .foregroundStyle(colors.textSecondary)
                        .padding(.top, 8)
                }
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: .json,
            defaultFilename: "flowapp-backup.json"
        ) { result in
            if case .success = result { message = "Data exported" }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json], onCompletion: importFile)
        .alert("Reset application?", isPresented: $showsResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                backupService.reset()
                message = "Application reset"
            }
        } message: {
            Text("All tasks, habits, focus sessions and settings will be deleted. This cannot be undone.")
        }
        .toast($message)
    }

    private func options<Value: Hashable>(_ title: String, _ values: [Value], selected: Value, title label: @escaping (Value) -> String, onSelect: @escaping (Value) -> Void) -> some View {
        ChipGroup(title: title) {
            ForEach(values, id: \.self) { value in
                FlowChip(title: label(value), isSelected: value == selected) { onSelect(value) }
            }
        }
    }

    private func action(_ title: String, _ subtitle: String, isDestructive: Bool = false, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(alignment: .leading) {
                Text(title).font(.flowBody1).foregroundStyle(isDestructive ? colors.error : colors.textMain)
                Text(subtitle).font(.flowCaption).foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func export() {
        if let data = try? backupService.export() {
            exportFile = BackupFile(data: data)
        } else {
            message = "Could not write the file"
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            message = "Could not read the file"
            return
        }
        message = switch backupService.import(data) {
        case let .success(tasks, habits, sessions): "Imported \(tasks) tasks, \(habits) habits, \(sessions) sessions"
        case .invalidFile: "This file is not a FlowApp export"
        case .unsupportedVersion(let version): "File version \(version) is newer than supported version \(Backup.currentVersion)"
        }
    }
}

private struct BackupFile: FileDocument {
    static let readableContentTypes = [UTType.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
