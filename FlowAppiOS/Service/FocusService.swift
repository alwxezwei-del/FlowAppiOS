import Foundation
import Observation

/// The focus timer and the history of finished sessions.
@MainActor
@Observable
final class FocusService {
    private(set) var active: ActiveSession?
    private(set) var sessions: [FocusSession] = []

    @ObservationIgnored private let sessionsFile: JSONFile<[FocusSession]>
    @ObservationIgnored private let activeFile: JSONFile<ActiveSession>
    @ObservationIgnored private let tasks: TaskService
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let time: TimeSource
    @ObservationIgnored private var ticker: Timer?

    /// Sessions shorter than this are treated as accidental taps and not saved.
    private static let minimumSeconds = 5

    init(tasks: TaskService, notifications: NotificationService, time: TimeSource, persistent: Bool = true) {
        self.tasks = tasks
        self.notifications = notifications
        self.time = time
        sessionsFile = JSONFile(persistent ? "focus_sessions.json" : nil)
        activeFile = JSONFile(persistent ? "timer.json" : nil)
        sessions = sessionsFile.load() ?? []
        active = activeFile.load()
        finishIfElapsed()
        updateTicker()
    }

    // MARK: Queries

    func sessions(in range: DateRange) -> [FocusSession] {
        sessions.filter { range.contains($0.endedAt, calendar: time.calendar) }
    }

    /// Focused time in the range, breaks excluded.
    func focusSeconds(in range: DateRange) -> Int {
        sessions(in: range).filter { $0.kind == .focus }.reduce(0) { $0 + $1.actualSeconds }
    }

    // MARK: Timer

    func requestNotificationPermission() {
        notifications.requestPermission()
    }

    func start(task: FlowTask?, kind: FocusKind, minutes: Int) {
        let now = time.now()
        // Breaks aren't counted towards a task, so a session with a task is always focus
        set(ActiveSession(
            taskId: task?.id,
            taskTitle: task?.title,
            categoryId: task?.categoryId,
            kind: task == nil ? kind : .focus,
            plannedSeconds: minutes * 60,
            startedAt: now,
            resumedAt: now
        ))
    }

    func togglePause() {
        guard var session = active else { return }
        let now = time.now()
        if session.isRunning {
            session.accumulated = session.elapsed(at: now)
            session.resumedAt = nil
        } else {
            session.resumedAt = now
        }
        set(session)
    }

    @discardableResult
    func stop() -> FocusSession? {
        finish(completed: false)
    }

    /// Ends the session if its time is up. Called every second and when the app comes back.
    @discardableResult
    func finishIfElapsed() -> FocusSession? {
        guard let active, active.isRunning, active.remaining(at: time.now()) <= 0 else { return nil }
        return finish(completed: true)
    }

    func replaceAll(sessions: [FocusSession]) {
        self.sessions = sessions
        sessionsFile.save(sessions)
    }

    private func set(_ session: ActiveSession?) {
        active = session
        activeFile.save(session)
        updateTicker()
        notifications.cancelTimerEnd()
        if let session, session.isRunning {
            notifications.scheduleTimerEnd(for: session, after: session.remaining(at: time.now()))
        }
    }

    private func finish(completed: Bool) -> FocusSession? {
        guard let active else { return nil }
        let now = time.now()
        let seconds = Int(min(active.elapsed(at: now), TimeInterval(active.plannedSeconds)))
        self.active = nil
        activeFile.save(nil)
        updateTicker()
        // When the time ran out the alert is due right now, so only a manual stop cancels it
        if !completed { notifications.cancelTimerEnd() }

        guard seconds >= Self.minimumSeconds else { return nil }
        let session = FocusSession(
            id: active.id,
            taskId: active.taskId,
            categoryId: active.categoryId,
            kind: active.kind,
            plannedSeconds: active.plannedSeconds,
            actualSeconds: seconds,
            startedAt: active.startedAt,
            endedAt: now,
            completed: completed
        )
        sessions.append(session)
        sessionsFile.save(sessions)
        if session.kind == .focus, let taskId = session.taskId {
            tasks.addFocusedTime(taskId, seconds: seconds)
        }
        return session
    }

    private func updateTicker() {
        guard active?.isRunning == true else {
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
}
