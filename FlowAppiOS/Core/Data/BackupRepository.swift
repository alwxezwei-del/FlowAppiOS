import Foundation

enum ImportResult: Equatable {
    /** Import succeeded, with imported record counts */
    case success(tasks: Int, habits: Int, sessions: Int)
    /** Not a FlowApp export or corrupted */
    case invalidFile
    /** File was created by a newer app version */
    case unsupportedVersion(fileVersion: Int, supportedVersion: Int)
}

/** JSON export/import. The only way to move data between devices */
@MainActor
struct BackupRepository {
    let database: FlowDatabase
    let settingsStore: SettingsStore
    let timeProvider: TimeProvider

    /** Serializes the whole database and settings to JSON */
    func export() throws -> String {
        let dto = BackupDto(
            version: BackupDto.currentVersion,
            exportedAt: timeProvider.now().epochMillis,
            settings: settingsStore.settings.dto,
            content: database.snapshot
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(dto), as: UTF8.self)
    }

    /** Replaces database contents with data from the file */
    func `import`(_ json: String) -> ImportResult {
        guard let dto = try? JSONDecoder().decode(BackupDto.self, from: Data(json.utf8)) else { return .invalidFile }
        if dto.version > BackupDto.currentVersion {
            return .unsupportedVersion(fileVersion: dto.version, supportedVersion: BackupDto.currentVersion)
        }
        database.replaceAll(with: dto.content)
        settingsStore.update(dto.settings.domain)
        return .success(tasks: dto.tasks.count, habits: dto.habits.count, sessions: dto.focusSessions.count)
    }

    /** Wipes the database and settings */
    func reset() {
        database.clear()
        settingsStore.clear()
    }
}

@MainActor
struct DefaultCategoriesInitializer {
    let database: FlowDatabase

    func seedIfEmpty() {
        guard database.categories.isEmpty else { return }
        [
            Category(name: "Work", color: .purple, icon: FlowIconKey.work, sortOrder: 0),
            Category(name: "Learning", color: .blue, icon: FlowIconKey.learning, sortOrder: 1),
            Category(name: "Personal", color: .orange, icon: FlowIconKey.personal, sortOrder: 2),
            Category(name: "Health", color: .green, icon: FlowIconKey.health, sortOrder: 3),
        ].forEach(database.createCategory)
    }
}
