import Foundation
import Observation

@MainActor
@Observable
final class SettingsService {
    private(set) var settings: AppSettings

    @ObservationIgnored private let file: JSONFile<AppSettings>

    init(fileName: String? = "settings.json") {
        file = JSONFile(fileName)
        settings = file.load() ?? AppSettings()
    }

    func update(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        file.save(settings)
    }

    func replace(with settings: AppSettings) {
        self.settings = settings
        file.save(settings)
    }

    func reset() {
        replace(with: AppSettings())
    }
}
