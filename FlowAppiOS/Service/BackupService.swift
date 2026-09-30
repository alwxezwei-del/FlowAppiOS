import Foundation
import Observation

enum ImportResult: Equatable {
    case success(tasks: Int, habits: Int, sessions: Int)
    case invalidFile
    case unsupportedVersion(Int)
}

/// JSON export and import, the only way to move data between devices.
/// The format is shared with Android, so files work in both directions.
@MainActor
@Observable
final class BackupService {
    @ObservationIgnored private let tasks: TaskService
    @ObservationIgnored private let habits: HabitService
    @ObservationIgnored private let focus: FocusService
    @ObservationIgnored private let settings: SettingsService
    @ObservationIgnored private let time: TimeSource

    init(tasks: TaskService, habits: HabitService, focus: FocusService, settings: SettingsService, time: TimeSource) {
        self.tasks = tasks
        self.habits = habits
        self.focus = focus
        self.settings = settings
        self.time = time
    }

    func export() throws -> Data {
        let backup = Backup(
            exportedAt: time.now(),
            settings: settings.settings,
            categories: tasks.categories,
            tasks: tasks.tasks,
            habits: habits.habits,
            habitCompletions: habits.completions,
            focusSessions: focus.sessions
        )
        return try FlowJSON.encoder(pretty: true).encode(backup)
    }

    /// Replaces everything with the file contents.
    func `import`(_ data: Data) -> ImportResult {
        struct Header: Decodable { let version: Int }

        // Check the version first: a newer file may not decode with the current models at all
        guard let header = try? FlowJSON.decoder().decode(Header.self, from: data) else { return .invalidFile }
        guard header.version <= Backup.currentVersion else { return .unsupportedVersion(header.version) }
        guard let backup = try? FlowJSON.decoder().decode(Backup.self, from: data) else { return .invalidFile }

        tasks.replaceAll(categories: backup.categories, tasks: backup.tasks)
        habits.replaceAll(habits: backup.habits, completions: backup.habitCompletions)
        focus.replaceAll(sessions: backup.focusSessions)
        settings.replace(with: backup.settings)
        return .success(tasks: backup.tasks.count, habits: backup.habits.count, sessions: backup.focusSessions.count)
    }

    func reset() {
        tasks.replaceAll(categories: [], tasks: [])
        habits.replaceAll(habits: [], completions: [])
        focus.replaceAll(sessions: [])
        settings.reset()
    }
}
