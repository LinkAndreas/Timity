import Foundation
import SwiftData
import UserNotifications

/// Schedules this device's event reminders as local notifications.
///
/// Events sync through iCloud but notifications don't, so every device schedules
/// its own from the synced events — after each change, sync and launch. Repeating
/// events get a reminder for their next occurrence, which moves on as they pass.
enum ReminderScheduler {
    /// When reminders for all-day events are sent on their day.
    static let allDayReminderHour = 9

    static var allDayReminderTime: Date {
        Calendar.autoupdatingCurrent.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: .now) ?? .now
    }

    /// iOS keeps at most 64 pending notifications per app.
    private static let limit = 60

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Couldn't request notification permission: \(error)")
            return false
        }
    }

    @MainActor
    static func reschedule(container: ModelContainer, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }

        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.reminderMinutes != nil })
        let events = (try? container.mainContext.fetch(descriptor)) ?? []
        let calendar = Calendar.autoupdatingCurrent

        let requests = events
            .compactMap { request(for: $0, now: now, calendar: calendar) }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(limit)

        center.removeAllPendingNotificationRequests()
        for item in requests {
            do {
                try await center.add(item.request)
            } catch {
                logger.error("Couldn't schedule a reminder: \(error)")
            }
        }
    }

    private static func request(for event: Event, now: Date, calendar: Calendar) -> (fireDate: Date, request: UNNotificationRequest)? {
        guard let minutes = event.reminderMinutes else { return nil }
        let start = event.startDate(in: calendar)

        // The next occurrence whose reminder is still ahead.
        var occurrence = EventSchedule.occurrence(of: start, recurrence: event.recurrence, onOrAfter: now, calendar: calendar)
        var fireDate = reminderDate(for: occurrence, minutes: minutes, isAllDay: event.isAllDay, calendar: calendar)
        if fireDate <= now, event.recurrence != .never {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: occurrence)) ?? occurrence
            occurrence = EventSchedule.occurrence(of: start, recurrence: event.recurrence, onOrAfter: tomorrow, calendar: calendar)
            fireDate = reminderDate(for: occurrence, minutes: minutes, isAllDay: event.isAllDay, calendar: calendar)
        }
        guard fireDate > now else { return nil }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = body(minutes: minutes, isAllDay: event.isAllDay, occurrence: occurrence)
        content.sound = .default
        content.threadIdentifier = event.id.uuidString
        content.userInfo = ["eventID": event.id.uuidString]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "\(event.id.uuidString)-\(Int(occurrence.timeIntervalSince1970))", content: content, trigger: trigger)
        return (fireDate, request)
    }

    private static func reminderDate(for occurrence: Date, minutes: Int, isAllDay: Bool, calendar: Calendar) -> Date {
        let reference = isAllDay
            ? calendar.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: occurrence) ?? occurrence
            : occurrence
        return reference.addingTimeInterval(TimeInterval(-minutes * 60))
    }

    private static func body(minutes: Int, isAllDay: Bool, occurrence: Date) -> String {
        if isAllDay {
            switch minutes / 1440 {
            case 0: return String(localized: "Today is the day!")
            case 1: return String(localized: "Tomorrow is the day.")
            case let days: return String(localized: "relative.inDays \(days)")
            }
        }
        if minutes == 0 {
            return String(localized: "Happening now.")
        }
        let time = occurrence.formatted(date: minutes >= 1440 ? .abbreviated : .omitted, time: .shortened)
        return String(localized: "Starts \(time).")
    }
}

/// Opens the event when the user taps one of its reminders.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let id = (response.notification.request.content.userInfo["eventID"] as? String).flatMap(UUID.init(uuidString:)) else {
            return
        }
        await MainActor.run { Navigator.shared.showEvent(id) }
    }

    /// Shows reminders even while Timity is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
