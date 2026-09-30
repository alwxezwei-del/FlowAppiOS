import Foundation
import Observation

/** Dependencies shared by all screens */
@MainActor
final class AppContainer {
    let timeProvider: TimeProvider
    let database: FlowDatabase
    let settingsStore: SettingsStore
    let notifications: FocusNotifications
    let timerController: FocusTimerController
    let backupRepository: BackupRepository
    let streakCalculator: HabitStreakCalculator
    let router = AppRouter()

    init(
        timeProvider: TimeProvider = SystemTimeProvider(),
        databaseURL: URL? = FlowDatabase.defaultFileURL,
        defaults: UserDefaults = .standard
    ) {
        self.timeProvider = timeProvider
        database = FlowDatabase(fileURL: databaseURL, timeProvider: timeProvider)
        settingsStore = SettingsStore(defaults: defaults)
        notifications = FocusNotifications()
        timerController = FocusTimerController(
            store: TimerStateStore(defaults: defaults),
            database: database,
            notifications: notifications,
            timeProvider: timeProvider
        )
        backupRepository = BackupRepository(database: database, settingsStore: settingsStore, timeProvider: timeProvider)
        streakCalculator = HabitStreakCalculator(timeProvider: timeProvider)
    }

    func initData() {
        DefaultCategoriesInitializer(database: database).seedIfEmpty()
        timerController.restore()
        timerController.finishIfElapsed()
    }
}

/** Bottom bar tab */
enum TopLevelDestination: CaseIterable, Hashable {
    case home, tasks, focus, statistics

    var title: String {
        switch self {
        case .home: "Home"
        case .tasks: "Tasks"
        case .focus: "Focus"
        case .statistics: "Stats"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: "house.fill"
        case .tasks: "checkmark.circle.fill"
        case .focus: "timer"
        case .statistics: "chart.bar.fill"
        }
    }

    var unselectedIcon: String {
        switch self {
        case .home: "house"
        case .tasks: "checkmark.circle"
        case .focus: "timer"
        case .statistics: "chart.bar"
        }
    }
}

enum FlowRoute: Hashable {
    /**
     * - Parameter taskId: nil = new task
     */
    case taskEditor(taskId: String?)
    /** - Parameter habitId: nil = new habit */
    case habitEditor(habitId: String?)
    case habitDetails(habitId: String)
    case habits
    case history
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: TopLevelDestination = .home
    var paths: [TopLevelDestination: [FlowRoute]] = [:]
    /** task chosen via "Start focus" elsewhere */
    var pendingFocusTaskId: String?

    func path(for tab: TopLevelDestination) -> [FlowRoute] { paths[tab] ?? [] }

    func setPath(_ path: [FlowRoute], for tab: TopLevelDestination) { paths[tab] = path }

    /** Whether the destination is a bottom-bar tab. The bar is hidden on detail screens */
    var isTopLevel: Bool { path(for: selectedTab).isEmpty }

    func navigate(_ route: FlowRoute) {
        paths[selectedTab, default: []].append(route)
    }

    func navigateUp() {
        guard !path(for: selectedTab).isEmpty else { return }
        paths[selectedTab]?.removeLast()
    }

    /**
     * Navigates to a bottom-bar tab
     */
    func navigateToTopLevel(_ tab: TopLevelDestination) {
        selectedTab = tab
    }

    func startFocus(taskId: String) {
        pendingFocusTaskId = taskId
        paths[.focus] = []
        selectedTab = .focus
    }
}
