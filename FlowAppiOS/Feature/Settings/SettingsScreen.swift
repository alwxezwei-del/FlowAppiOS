import SwiftUI
import UniformTypeIdentifiers
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var resetDialogVisible = false
    var message: String?

    @ObservationIgnored private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var settings: AppSettings { container.settingsStore.settings }

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        container.settingsStore.update(transform)
    }

    func export() -> BackupDocument? {
        guard let json = try? container.backupRepository.export() else {
            message = "Could not write the file"
            return nil
        }
        return BackupDocument(json: json)
    }

    func exportFinished(_ result: Result<URL, Error>) {
        switch result {
        case .success: message = "Data exported"
        case .failure(let error as CocoaError) where error.code == .userCancelled: break
        case .failure: message = "Could not write the file"
        }
    }

    func importFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let json = try? String(contentsOf: url, encoding: .utf8) else {
            message = "Could not read the file"
            return
        }
        message = switch container.backupRepository.import(json) {
        case .success(let tasks, let habits, let sessions): "Imported \(tasks) tasks, \(habits) habits, \(sessions) sessions"
        case .invalidFile: "This file is not a FlowApp export"
        case .unsupportedVersion(let file, let supported): "File version \(file) is newer than supported version \(supported)"
        }
    }

    func reset() {
        container.backupRepository.reset()
        resetDialogVisible = false
        message = "Application reset"
    }
}

/** Duration options offered in settings. */
private enum SettingsPresets {
    static let focus = [15, 25, 45, 60]
    static let shortBreak = [3, 5, 10]
    static let longBreak = [10, 15, 20, 30]
    static let startOfWeek: [DayOfWeek] = [.monday, .sunday]
}

extension ThemeMode {
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/** Settings */
struct SettingsScreen: View {
    private let router: AppRouter
    @State private var viewModel: SettingsViewModel
    @State private var exportDocument: BackupDocument?
    @State private var importerVisible = false

    @Environment(\.flowColors) private var colors

    init(container: AppContainer) {
        router = container.router
        _viewModel = State(initialValue: SettingsViewModel(container: container))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let settings = viewModel.settings

        FlowScaffold(topBar: { FlowTopBar(title: "Settings", onBack: router.navigateUp) }) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FlowSpacers.x12) {
                    SectionHeader(title: "Timer")
                    FlowCard {
                        VStack(alignment: .leading, spacing: FlowSpacers.x16) {
                            ChipRow(title: "Focus duration", values: SettingsPresets.focus, selected: settings.focusMinutes, label: { "\($0) min" }) { value in
                                viewModel.update { $0.focusMinutes = value }
                            }
                            ChipRow(title: "Short break", values: SettingsPresets.shortBreak, selected: settings.shortBreakMinutes, label: { "\($0) min" }) { value in
                                viewModel.update { $0.shortBreakMinutes = value }
                            }
                            ChipRow(title: "Long break", values: SettingsPresets.longBreak, selected: settings.longBreakMinutes, label: { "\($0) min" }) { value in
                                viewModel.update { $0.longBreakMinutes = value }
                            }
                        }
                    }

                    SectionHeader(title: "Appearance")
                    FlowCard {
                        VStack(alignment: .leading, spacing: FlowSpacers.x16) {
                            ChipRow(title: "Theme", values: ThemeMode.allCases, selected: settings.themeMode, label: \.label) { value in
                                viewModel.update { $0.themeMode = value }
                            }
                            VStack(alignment: .leading, spacing: FlowSpacers.x8) {
                                Text("Accent color").font(FlowTypography.body2).foregroundStyle(colors.textSecondary)
                                HStack(spacing: FlowSpacers.x8) {
                                    ForEach(AccentColor.allCases, id: \.self) { accent in
                                        ColorOption(color: colors.accent(accent), selected: accent == settings.accentColor, size: 32) {
                                            viewModel.update { $0.accentColor = accent }
                                        }
                                    }
                                }
                            }
                            ChipRow(title: "Start of week", values: SettingsPresets.startOfWeek, selected: settings.startOfWeek, label: \.displayName) { value in
                                viewModel.update { $0.startOfWeek = value }
                            }
                            HStack(spacing: FlowSpacers.x12) {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Notifications").font(FlowTypography.body1).foregroundStyle(colors.textMain)
                                    Text("Timer notification and habit reminders").font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                FlowSwitch(
                                    isOn: Binding(get: { settings.notificationsEnabled }, set: { value in viewModel.update { $0.notificationsEnabled = value } }),
                                    accessibilityLabel: "Notifications"
                                )
                            }
                        }
                    }

                    SectionHeader(title: "Data")
                    FlowCard {
                        VStack(spacing: FlowSpacers.x4) {
                            ActionRow(title: "Export data", subtitle: "Save everything as a JSON file") {
                                exportDocument = viewModel.export()
                            }
                            ActionRow(title: "Import data", subtitle: "Restore from a JSON file") {
                                importerVisible = true
                            }
                            ActionRow(title: "Reset application", subtitle: "Delete all tasks, habits and sessions", destructive: true) {
                                viewModel.resetDialogVisible = true
                            }
                        }
                    }

                    FlowCard {
                        Text("FlowApp").font(FlowTypography.body1).foregroundStyle(colors.textMain)
                        Text("Version \(viewModel.appVersion)").font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
                        Text("All data stays on this device. No account, no backend, no network.")
                            .font(FlowTypography.caption)
                            .foregroundStyle(colors.textSecondary)
                            .padding(.top, FlowSpacers.x8)
                    }
                }
                .flowListPadding()
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "flowapp-backup.json",
            onCompletion: viewModel.exportFinished
        )
        .fileImporter(isPresented: $importerVisible, allowedContentTypes: [.json, .data], onCompletion: viewModel.importFile)
        .alert("Reset application?", isPresented: $viewModel.resetDialogVisible) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { viewModel.reset() }
        } message: {
            Text("All tasks, habits, focus sessions and settings will be deleted. This cannot be undone.")
        }
        .flowToast(message: $viewModel.message)
    }
}

private struct ChipRow<T: Hashable>: View {
    let title: String
    let values: [T]
    let selected: T
    let label: (T) -> String
    let onSelect: (T) -> Void

    var body: some View {
        EditorSection(title: title) {
            ForEach(values, id: \.self) { value in
                FlowChip(text: label(value), selected: value == selected) { onSelect(value) }
            }
        }
    }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String
    var destructive = false
    let onClick: () -> Void

    @Environment(\.flowColors) private var colors

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(FlowTypography.body1).foregroundStyle(destructive ? colors.error : colors.textMain)
                Text(subtitle).font(FlowTypography.caption).foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FlowSpacers.x12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    /** export file contents */
    let json: String

    init(json: String) {
        self.json = json
    }

    init(configuration: ReadConfiguration) throws {
        json = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}
