import Foundation

struct TimerStateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> TimerState {
        guard let sessionId = defaults.string(forKey: Keys.sessionId),
              let plannedSeconds = defaults.object(forKey: Keys.plannedSeconds) as? Int else { return .idle }

        let session = RunningSession(
            id: sessionId,
            taskId: defaults.string(forKey: Keys.taskId),
            taskTitle: defaults.string(forKey: Keys.taskTitle),
            categoryId: defaults.string(forKey: Keys.categoryId),
            kind: .parse(defaults.string(forKey: Keys.kind)),
            plannedSeconds: plannedSeconds,
            startedAt: Date(timeIntervalSince1970: defaults.double(forKey: Keys.sessionStartedAt))
        )
        let accumulated = defaults.double(forKey: Keys.accumulated)

        if defaults.bool(forKey: Keys.running) {
            return .running(
                session: session,
                startedAt: Date(timeIntervalSince1970: defaults.double(forKey: Keys.resumedAt)),
                accumulated: accumulated
            )
        }
        return .paused(session: session, accumulated: accumulated)
    }

    func write(_ state: TimerState) {
        guard let session = state.runningSession else {
            clear()
            return
        }

        defaults.set(session.id, forKey: Keys.sessionId)
        defaults.set(session.taskId, forKey: Keys.taskId)
        defaults.set(session.taskTitle, forKey: Keys.taskTitle)
        defaults.set(session.categoryId, forKey: Keys.categoryId)
        defaults.set(session.kind.rawValue, forKey: Keys.kind)
        defaults.set(session.plannedSeconds, forKey: Keys.plannedSeconds)
        defaults.set(session.startedAt.timeIntervalSince1970, forKey: Keys.sessionStartedAt)

        switch state {
        case .running(_, let startedAt, let accumulated):
            defaults.set(true, forKey: Keys.running)
            defaults.set(startedAt.timeIntervalSince1970, forKey: Keys.resumedAt)
            defaults.set(accumulated, forKey: Keys.accumulated)
        case .paused(_, let accumulated):
            defaults.set(false, forKey: Keys.running)
            defaults.set(accumulated, forKey: Keys.accumulated)
        case .idle:
            break
        }
    }

    func clear() {
        Keys.all.forEach(defaults.removeObject(forKey:))
    }

    private enum Keys {
        static let sessionId = "timer_session_id"
        static let taskId = "timer_task_id"
        static let taskTitle = "timer_task_title"
        static let categoryId = "timer_category_id"
        static let kind = "timer_kind"
        static let plannedSeconds = "timer_planned_seconds"
        static let accumulated = "timer_accumulated_seconds"
        static let sessionStartedAt = "timer_session_started_at"
        static let resumedAt = "timer_resumed_at"
        static let running = "timer_running"

        static let all = [sessionId, taskId, taskTitle, categoryId, kind, plannedSeconds, accumulated, sessionStartedAt, resumedAt, running]
    }
}
