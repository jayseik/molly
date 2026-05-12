import Foundation
import UserNotifications

/// Implements the plan's probe-failure alerting policy (`>=5 misses within ≥3 min wall time`, max once/hour suppression).
@MainActor
final class NotificationThrottleCoordinator: NSObject {

    static let shared = NotificationThrottleCoordinator()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Recent failure timestamps for the Connectivity lane streak.
    private var failureMoments: [Date] = []
    private var hourlySuppressUntil: Date?

    func resetFailureTimeline() {
        failureMoments.removeAll()
    }

    /// Record another failed Connectivity ladder iteration (timeline cleared after successes elsewhere).
    func failureConnectivityProbeTick(currentFailures _: Int,
                                      notificationsAllowed: Bool) {
        guard notificationsAllowed else {
            failureMoments.removeAll()
            return
        }

        let now = Date()
        failureMoments.append(now)

        guard failureMoments.count >= 5 else { return }
        guard let pivot = failureMoments.dropFirst(failureMoments.count - 5).first else { return }
        guard now.timeIntervalSince(pivot) >= 180 else { return }

        if let suppressed = hourlySuppressUntil, suppressed > now {
            return
        }

        postConnectivityAlert()
        failureMoments.removeAll()
        hourlySuppressUntil = now.addingTimeInterval(3600)
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted == false {
                MollyDiagnostics.write("Notifications permission denied — alerts disabled")
            }
        } catch {
            MollyDiagnostics.write("Notification authorization error \(error)")
        }
    }

    private func postConnectivityAlert() {
        let content = UNMutableNotificationContent()
        content.title = "Molly connectivity probing struggle"
        content.body =
            "Five consecutive probe ladders failed spanning several minutes — verify hotspot/power settings."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "molly.connectivity.failure",
            content: content,
            trigger: nil)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func notifyTimerExpiredPlainCopy() {
        let content = UNMutableNotificationContent()
        content.title = "Molly session timer ended"
        content.body =
            "Awake / Connectivity lanes turned off automatically per your countdown."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "molly.timer.expiry",
            content: content,
            trigger: nil)

        UNUserNotificationCenter.current().add(request)
    }

}

extension NotificationThrottleCoordinator: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        completionHandler([.banner, .badge, .sound])
    }

}

/// Minimal NSLog wrapper for launches without AppKit dialogs.
enum MollyDiagnostics {
    static func write(_ line: String) {
        fputs("\(line)\n", stderr)
    }
}
