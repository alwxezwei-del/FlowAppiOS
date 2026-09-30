import Foundation

/// JSON coding shared by storage and backups. Matches the Android kotlinx.serialization setup.
enum FlowJSON {
    static func encoder(pretty: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

/// A value kept as a JSON file in Application Support. Without a name it lives only in memory (tests).
struct JSONFile<Value: Codable> {
    private let url: URL?

    init(_ name: String?) {
        guard let name else {
            url = nil
            return
        }
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appending(path: name)
    }

    func load() -> Value? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? FlowJSON.decoder().decode(Value.self, from: data)
    }

    func save(_ value: Value?) {
        guard let url else { return }
        guard let value, let data = try? FlowJSON.encoder().encode(value) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: .atomic)
    }
}

/// Source of "now", so tests can pin the date.
protocol TimeSource {
    func now() -> Date
    var calendar: Calendar { get }
}

extension TimeSource {
    var today: LocalDate { LocalDate.from(now(), calendar: calendar) }

    func day(of date: Date) -> LocalDate { LocalDate.from(date, calendar: calendar) }
}

struct SystemTimeSource: TimeSource {
    func now() -> Date { Date() }
    var calendar: Calendar { Calendar.current }
}

/// Backup file layout, identical to the Android export.
struct Backup: Codable {
    static let currentVersion = 1

    var version = Backup.currentVersion
    var exportedAt: Date
    var settings: AppSettings
    var categories: [Category]
    var tasks: [FlowTask]
    var habits: [Habit]
    var habitCompletions: [HabitCompletion]
    var focusSessions: [FocusSession]
}
