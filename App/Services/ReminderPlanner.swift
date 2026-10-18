import Foundation

/// A notification to send at a moment.
nonisolated struct PlannedReminder: Equatable, Sendable {
    let id: String
    let eventID: UUID
    let title: String
    let body: String
    let fireDate: Date
}

/// Works out this device's event reminders.
///
/// Events sync through iCloud but notifications don't, so every device plans its
/// own from the synced events. Repeating events get a reminder for their next
/// occurrence, which moves on as they pass.
nonisolated enum ReminderPlanner {
    /// When reminders for all-day events are sent on their day.
    static let allDayReminderHour = 9

    /// iOS keeps at most 64 pending notifications per app.
    static let limit = 60

    static func allDayReminderTime(calendar: Calendar = .autoupdatingCurrent) -> Date {
        calendar.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: .now) ?? .now
    }

    /// The reminders to schedule, soonest first: the ones asked for, then milestones.
    static func reminders(
        for events: [EventSnapshot],
        includingMilestones: Bool,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [PlannedReminder] {
        let active = events.filter { !$0.isArchived }
        let reminders = active
            .compactMap { reminder(for: $0, now: now, calendar: calendar) }
            .sorted { $0.fireDate < $1.fireDate }
        let milestones = includingMilestones
            ? active
                .filter { !$0.isYearUnknown }
                .flatMap { milestoneReminders(for: $0, now: now, calendar: calendar) }
                .sorted { $0.fireDate < $1.fireDate }
            : []
        // Reminders first: they were asked for one by one.
        return Array(reminders.prefix(limit) + milestones.prefix(max(0, limit - reminders.count)))
    }

    private static func reminder(for event: EventSnapshot, now: Date, calendar: Calendar) -> PlannedReminder? {
        guard let minutes = event.reminderMinutes else { return nil }
        let start = event.startDate(in: calendar)
        // Repeats keep their wall-clock time where the event happens, as its countdown does.
        var eventCalendar = calendar
        if let zone = event.timeZone { eventCalendar.timeZone = zone }

        // The next occurrence whose reminder is still ahead.
        let rule = event.rule
        var occurrence = rule.occurrence(of: start, onOrAfter: now, calendar: eventCalendar).date
        var fireDate = reminderDate(for: occurrence, minutes: minutes, isAllDay: event.isAllDay, calendar: calendar)
        if fireDate <= now, event.recurrence != .never {
            let tomorrow = eventCalendar.date(byAdding: .day, value: 1, to: eventCalendar.startOfDay(for: occurrence)) ?? occurrence
            occurrence = rule.occurrence(of: start, onOrAfter: tomorrow, calendar: eventCalendar).date
            fireDate = reminderDate(for: occurrence, minutes: minutes, isAllDay: event.isAllDay, calendar: calendar)
        }
        guard fireDate > now else { return nil }

        return PlannedReminder(
            id: "\(event.id.uuidString)-\(Int(occurrence.timeIntervalSince1970))",
            eventID: event.id,
            title: event.title,
            body: body(minutes: minutes, isAllDay: event.isAllDay, occurrence: occurrence),
            fireDate: fireDate
        )
    }

    /// The next milestones within three months, e.g. "10,000 days since Anna's birth".
    private static func milestoneReminders(for event: EventSnapshot, now: Date, calendar: Calendar) -> [PlannedReminder] {
        let start = event.startDate(in: calendar)
        let horizon = now.addingTimeInterval(90 * 86_400)
        return Milestones.upcoming(since: start, after: now, limit: 3, calendar: calendar)
            .filter { $0.date < horizon }
            .compactMap { milestone in
                // Whole days are celebrated in the morning; hours, minutes and seconds at the moment itself.
                let isDayBased = [.year, .month, .week, .day].contains(milestone.unit)
                let fireDate = isDayBased
                    ? calendar.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: milestone.date) ?? milestone.date
                    : milestone.date
                guard fireDate > now else { return nil }
                return PlannedReminder(
                    id: "\(event.id.uuidString)-milestone-\(milestone.id)",
                    eventID: event.id,
                    title: String(localized: "reminders.milestone \(event.title)"),
                    body: String(localized: "reminders.milestoneBody \(milestone.value.formatted()) \(CountdownText.unit(milestone.unit, value: Int(clamping: milestone.value))) \(event.title)"),
                    fireDate: fireDate
                )
            }
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
            case 0: return String(localized: "reminders.todayIsTheDay")
            case 1: return String(localized: "reminders.tomorrowIsTheDay")
            case let days: return String(localized: "common.relativeInDays \(days)")
            }
        }
        if minutes == 0 {
            return String(localized: "reminders.happeningNow")
        }
        let time = occurrence.formatted(date: minutes >= 1440 ? .abbreviated : .omitted, time: .shortened)
        return String(localized: "reminders.starts \(time)")
    }
}
