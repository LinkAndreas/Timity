import Foundation
import UserNotifications

/// Sends this device's reminders.
nonisolated protocol ReminderScheduling: Sendable {
    /// Asks for permission to send notifications, the first time.
    @discardableResult
    func requestAuthorization() async -> Bool
    /// Replaces every scheduled reminder with these.
    func schedule(_ reminders: [PlannedReminder]) async
}

/// Reminders as local notifications.
nonisolated struct UserNotificationReminderScheduler: ReminderScheduling {
    private var center: UNUserNotificationCenter { .current() }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Couldn't request notification permission: \(error)")
            return false
        }
    }

    func schedule(_ reminders: [PlannedReminder]) async {
        await Self.replaceAll(with: reminders)
    }

    /// In the background: there can be a few hundred reminders to add one by one.
    @concurrent
    private static func replaceAll(with reminders: [PlannedReminder]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }

        // Every event reminder goes; the nightly bedtime reminder isn't one of them.
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0 != UserNotificationBedtimeReminder.identifier })
        let calendar = Calendar.autoupdatingCurrent
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = reminder.eventID.uuidString
            content.userInfo = [NotificationTapRouter.eventIDKey: reminder.eventID.uuidString]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
            } catch {
                logger.error("Couldn't schedule a reminder: \(error)")
            }
        }
    }
}

/// Opens the event when the user taps one of its reminders, and shows reminders
/// even while Timity is open.
nonisolated final class NotificationTapRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let eventIDKey = "eventID"

    private let openEvent: @MainActor @Sendable (UUID) -> Void

    init(openEvent: @escaping @MainActor @Sendable (UUID) -> Void) {
        self.openEvent = openEvent
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let value = response.notification.request.content.userInfo[Self.eventIDKey] as? String
        guard let id = value.flatMap(UUID.init(uuidString:)) else { return }
        await openEvent(id)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
