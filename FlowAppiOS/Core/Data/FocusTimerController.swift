import Foundation
import Observation

/**
 * Owns the active focus session state, shared by the screen and notification
 */
@MainActor
@Observable
final class FocusTimerController {
    private(set) var state: TimerState = .idle

    @ObservationIgnored private let store: TimerStateStore
    @ObservationIgnored private let database: FlowDatabase
    @ObservationIgnored private let notifications: FocusNotifications
    @ObservationIgnored private let timeProvider: TimeProvider
    @ObservationIgnored private var ticker: Timer?

    init(store: TimerStateStore, database: FlowDatabase, notifications: FocusNotifications, timeProvider: TimeProvider) {
        self.store = store
        self.database = database
        self.notifications = notifications
        self.timeProvider = timeProvider
    }

    func start(_ session: RunningSession) {
        apply(.running(session: session, startedAt: timeProvider.now(), accumulated: 0))
    }

    func pause() {
        guard case .running(let session, _, _) = state else { return }
        apply(.paused(session: session, accumulated: state.elapsed(at: timeProvider.now())))
    }

    func resume() {
        guard case .paused(let session, let accumulated) = state else { return }
        apply(.running(session: session, startedAt: timeProvider.now(), accumulated: accumulated))
    }

    /** Stops the timer and saves the session */
    @discardableResult
    func stop(completed: Bool) -> FocusSession? {
        finish(completed: completed)
    }

    /** Finishes the interval if its time has already elapsed */
    @discardableResult
    func finishIfElapsed() -> FocusSession? {
        guard case .running(let session, _, _) = state,
              state.elapsed(at: timeProvider.now()) >= TimeInterval(session.plannedSeconds) else { return nil }
        return finish(completed: true)
    }

    /** Restores state after process restart */
    func restore() {
        state = store.read()
        updateTicker()
    }

    private func apply(_ next: TimerState) {
        state = next
        store.write(next)
        updateTicker()
        notifications.cancelFinished()
        if case .running(let session, _, _) = next {
            notifications.scheduleFinished(session: session, after: next.remaining(at: timeProvider.now()))
        }
    }

    private func finish(completed: Bool) -> FocusSession? {
        guard let session = state.runningSession else { return nil }

        let now = timeProvider.now()
        let elapsed = Int(min(max(state.elapsed(at: now), 0), TimeInterval(session.plannedSeconds)))

        var focusSession: FocusSession?
        if elapsed >= Self.minSessionSeconds {
            let saved = FocusSession(
                id: session.id,
                taskId: session.taskId,
                categoryId: session.categoryId,
                kind: session.kind,
                plannedSeconds: session.plannedSeconds,
                actualSeconds: elapsed,
                startedAt: session.startedAt,
                endedAt: now,
                completed: completed
            )
            database.saveSession(saved)
            if session.kind == .focus, let taskId = session.taskId {
                completeTaskIfDone(taskId: taskId, elapsed: elapsed)
            }
            focusSession = saved
        }

        store.clear()
        state = .idle
        updateTicker()
        // Stopped by the user: the pending "finished" alert must not fire
        if !completed { notifications.cancelFinished() }
        return focusSession
    }

    private func completeTaskIfDone(taskId: String, elapsed: Int) {
        database.addFocusedTime(taskId: taskId, seconds: elapsed)
        guard let task = database.task(id: taskId) else { return }
        if task.status == .active && task.focusProgress >= 1 {
            database.setStatus(taskId: taskId, status: .completed)
        }
    }

    /** Per-second loop: finishes the interval when time is up. */
    private func updateTicker() {
        guard state.isRunning else {
            ticker?.invalidate()
            ticker = nil
            return
        }
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.finishIfElapsed() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private static let minSessionSeconds = 5
}
