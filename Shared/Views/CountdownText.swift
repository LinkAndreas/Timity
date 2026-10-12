import SwiftUI

/// The words around Timity's numbers, localized with proper plurals.
enum CountdownText {
    /// The unit's name for `value`, without the number: "day" or "days".
    static func unit(_ unit: TimeUnit, value: Int) -> String {
        switch unit {
        case .year: String(localized: "unit.year \(value)")
        case .month: String(localized: "unit.month \(value)")
        case .week: String(localized: "unit.week \(value)")
        case .day: String(localized: "unit.day \(value)")
        case .hour: String(localized: "unit.hour \(value)")
        case .minute: String(localized: "unit.minute \(value)")
        case .second: String(localized: "unit.second \(value)")
        }
    }

    /// The caption under a day count: "days to go", "days ago", or "Today".
    static func dayCaption(_ countdown: Countdown) -> String {
        switch countdown.direction {
        case _ where countdown.isToday: String(localized: "Today")
        case .future: String(localized: "caption.daysToGo \(countdown.days)")
        case .past: String(localized: "caption.daysAgo \(countdown.days)")
        case .present: String(localized: "Today")
        }
    }

    /// A short phrase for lists and widgets: "Today", "Tomorrow", "in 12 days", "3 days ago".
    static func relativeDays(_ countdown: Countdown) -> String {
        switch (countdown.direction, countdown.days) {
        case (_, 0): String(localized: "Today")
        case (.future, 1): String(localized: "Tomorrow")
        case (.past, 1): String(localized: "Yesterday")
        case (.past, let days): String(localized: "relative.daysAgo \(days)")
        default: String(localized: "relative.inDays \(countdown.days)")
        }
    }

    /// "30th" for the 30th birthday, in the user's language.
    static func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: number as NSNumber) ?? "\(number)"
    }

    /// The whole breakdown as one sentence for VoiceOver: "2 weeks, 3 days, 4 hours".
    static func spokenBreakdown(_ breakdown: TimeBreakdown, includingSeconds: Bool) -> String {
        var components = DateComponents()
        components.year = breakdown.years
        components.month = breakdown.months
        components.weekOfMonth = breakdown.weeks
        components.day = breakdown.days
        components.hour = breakdown.hours
        components.minute = breakdown.minutes
        if includingSeconds { components.second = breakdown.seconds }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute, .second]
        return formatter.string(from: components) ?? ""
    }

    /// A total such as 12.5 or 1,234, with at most two decimals.
    static func total(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension Recurrence {
    var name: LocalizedStringResource {
        switch self {
        case .never: "Never"
        case .weekly: "Every Week"
        case .monthly: "Every Month"
        case .yearly: "Every Year"
        }
    }
}

extension Countdown {
    /// "14:00 Japan Time" for an event in another time zone; `nil` when it's in the user's own.
    var eventTimeText: String? {
        guard !isAllDay, let zone = eventTimeZone,
              zone.secondsFromGMT(for: target) != TimeZone.autoupdatingCurrent.secondsFromGMT(for: target)
        else { return nil }
        let time = target.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
        let name = zone.localizedName(for: .shortGeneric, locale: .autoupdatingCurrent) ?? zone.identifier
        return "\(time) \(name)"
    }

    /// The date of the target occurrence, with the time unless the event is all-day.
    var targetText: String {
        isAllDay
            ? target.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
            : target.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
    }
}
