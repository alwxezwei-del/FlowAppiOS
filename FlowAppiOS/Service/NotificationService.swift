import Foundation
import UserNotifications

/// Local notifications. iOS can't keep a live timer notification like Android does,
/// so we schedule a single alert for the moment the timer runs out.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private static let timerEndId = "focus_finished"

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleTimerEnd(for session: ActiveSession, after seconds: TimeInterval) {
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = session.kind == .focus ? "Focus session complete" : "Break is over"
        content.body = session.taskTitle ?? "\(session.plannedSeconds / 60) min"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.timerEndId, content: content, trigger: trigger))
    }

    func cancelTimerEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.timerEndId])
    }

    // Show the alert even when the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
