import Foundation
import UserNotifications

/// The nightly bedtime reminder from the Bedtime calculator.
nonisolated protocol BedtimeReminding: Sendable {
    /// Reminds every night at `minuteOfDay` (minutes after midnight), replacing any
    /// earlier reminder; `false` when notifications aren't allowed.
    func schedule(minuteOfDay: Int, title: String, body: String) async -> Bool
    func cancel() async
}

/// The bedtime reminder as a repeating local notification, kept apart from event
/// reminders so rescheduling those leaves it alone.
nonisolated struct UserNotificationBedtimeReminder: BedtimeReminding {
    static let identifier = "bedtime"

    private var center: UNUserNotificationCenter { .current() }

    func schedule(minuteOfDay: Int, title: String, body: String) async -> Bool {
        guard await UserNotificationReminderScheduler().requestAuthorization() else { return false }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = Self.identifier
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60),
            repeats: true
        )
        do {
            try await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
            return true
        } catch {
            logger.error("Couldn't schedule the bedtime reminder: \(error)")
            return false
        }
    }

    func cancel() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
