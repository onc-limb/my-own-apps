import Foundation
import UserNotifications

@MainActor @Observable
final class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()

    // MARK: - Init

    private init() {}

    // MARK: - Authorization

    /// Request notification permission from the user.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("[NotificationService] Authorization granted: \(granted)")
        } catch {
            print("[NotificationService] Authorization failed: \(error)")
        }
    }

    // MARK: - Schedule

    /// Schedule a local notification for when a habit timer finishes.
    func scheduleTimerNotification(habitName: String, seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "タイマー終了"
        content.body = "\(habitName) の時間です"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: seconds,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "habiterm-timer",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationService] Failed to schedule notification: \(error)")
            }
        }
    }

    // MARK: - Cancel

    /// Cancel the scheduled timer notification.
    func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["habiterm-timer"])
    }
}
