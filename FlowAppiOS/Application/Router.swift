import Observation

enum AppTab: CaseIterable, Hashable {
    case home, tasks, focus, stats
}

enum Route: Hashable {
    /// `nil` opens the editor for a new task.
    case taskEditor(taskId: String?)
    case habitEditor(habitId: String?)
    case habitDetails(habitId: String)
    case habits
    case history
    case settings
}

/// Selected tab and a navigation stack per tab.
@MainActor
@Observable
final class Router {
    var tab = AppTab.home
    var paths: [AppTab: [Route]] = [:]
    /// Set by "Start focus" on a task, picked up by the Focus screen.
    var focusTaskId: String?

    /// The bottom bar is only shown on the tab roots.
    var isAtRoot: Bool { paths[tab, default: []].isEmpty }

    func push(_ route: Route) {
        paths[tab, default: []].append(route)
    }

    func pop(_ count: Int = 1) {
        paths[tab, default: []].removeLast(min(count, paths[tab, default: []].count))
    }

    func startFocus(taskId: String) {
        focusTaskId = taskId
        paths[.focus] = []
        tab = .focus
    }
}
