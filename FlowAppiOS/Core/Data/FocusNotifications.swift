import Foundation
import UserNotifications

final class FocusNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /** Alerting notification with sound when the interval reaches zero. */
    func scheduleFinished(session: RunningSession, after seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = session.kind == .focus ? "Focus session complete" : "Break is over"
        content.body = session.taskTitle ?? "\(session.plannedSeconds / 60) min"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.finishedId, content: content, trigger: trigger))
    }

    func cancelFinished() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.finishedId])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    private static let finishedId = "focus_finished"
}
