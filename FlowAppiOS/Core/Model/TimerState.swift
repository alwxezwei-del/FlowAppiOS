import Foundation

/**
 * Immutable part of a running session
 */
struct RunningSession: Hashable {
    /** id of the resulting ``FocusSession`` */
    var id: String = newId()
    var taskId: String? = nil
    /** for the notification, so it does not need DB access */
    var taskTitle: String? = nil
    var categoryId: String? = nil
    var kind: FocusKind = .focus
    var plannedSeconds: Int
    /** first start time */
    var startedAt: Date
}

/**
 * Focus timer state, the single source of truth for the screen and notification
 *
 * Stored as `startedAt` + `accumulated` rather than remaining seconds, so it can be restored after
 * process death just by reading the clock.
 */
enum TimerState: Hashable {
    case idle

    /**
     * Timer running
     *
     * - Parameter startedAt: last start or resume time
     * - Parameter accumulated: time accumulated before the last pause
     */
    case running(session: RunningSession, startedAt: Date, accumulated: TimeInterval)

    /**
     * Timer paused
     *
     * - Parameter accumulated: time accumulated at pause
     */
    case paused(session: RunningSession, accumulated: TimeInterval)

    /** Session if the timer is running or paused */
    var runningSession: RunningSession? {
        switch self {
        case .idle: nil
        case .running(let session, _, _): session
        case .paused(let session, _): session
        }
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    func elapsed(at now: Date) -> TimeInterval {
        switch self {
        case .idle: 0
        case .paused(_, let accumulated): accumulated
        case .running(_, let startedAt, let accumulated): accumulated + now.timeIntervalSince(startedAt)
        }
    }

    func remaining(at now: Date) -> TimeInterval {
        guard let session = runningSession else { return 0 }
        return max(TimeInterval(session.plannedSeconds) - elapsed(at: now), 0)
    }

    func progress(at now: Date) -> Double {
        guard let session = runningSession, session.plannedSeconds > 0 else { return 0 }
        return min(max(elapsed(at: now) / TimeInterval(session.plannedSeconds), 0), 1)
    }
}
