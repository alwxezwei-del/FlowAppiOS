import SwiftUI

/// Creates the services once and hands them to the view tree through the environment.
@MainActor
final class AppServices {
    let time: TimeSource
    let tasks: TaskService
    let habits: HabitService
    let focus: FocusService
    let settings: SettingsService
    let stats: StatsService
    let backup: BackupService
    let notifications: NotificationService
    let router = Router()

    init(time: TimeSource = SystemTimeSource(), persistent: Bool = true) {
        self.time = time
        notifications = NotificationService()
        tasks = TaskService(time: time, fileName: persistent ? "tasks.json" : nil)
        habits = HabitService(time: time, fileName: persistent ? "habits.json" : nil)
        settings = SettingsService(fileName: persistent ? "settings.json" : nil)
        focus = FocusService(tasks: tasks, notifications: notifications, time: time, persistent: persistent)
        stats = StatsService(tasks: tasks, habits: habits, focus: focus, settings: settings, time: time)
        backup = BackupService(tasks: tasks, habits: habits, focus: focus, settings: settings, time: time)
        tasks.seedDefaultCategories()
    }
}

extension View {
    func environment(_ services: AppServices) -> some View {
        environment(services.tasks)
            .environment(services.habits)
            .environment(services.focus)
            .environment(services.settings)
            .environment(services.stats)
            .environment(services.backup)
            .environment(services.router)
            .environment(\.timeSource, services.time)
    }
}

extension EnvironmentValues {
    @Entry var timeSource: TimeSource = SystemTimeSource()
}
