import SwiftUI

/// The words around Timity's numbers, localized with proper plurals.
nonisolated enum CountdownText {
    /// The unit's name for `value`, without the number: "day" or "days".
    static func unit(_ unit: TimeUnit, value: Int) -> String {
        let isSingular = abs(value) == 1
        switch unit {
        case .year: return isSingular ? String(localized: "unit.year.singular") : String(localized: "unit.year.plural")
        case .month: return isSingular ? String(localized: "unit.month.singular") : String(localized: "unit.month.plural")
        case .week: return isSingular ? String(localized: "unit.week.singular") : String(localized: "unit.week.plural")
        case .day: return isSingular ? String(localized: "unit.day.singular") : String(localized: "unit.day.plural")
        case .hour: return isSingular ? String(localized: "unit.hour.singular") : String(localized: "unit.hour.plural")
        case .minute: return isSingular ? String(localized: "unit.minute.singular") : String(localized: "unit.minute.plural")
        case .second: return isSingular ? String(localized: "unit.second.singular") : String(localized: "unit.second.plural")
        }
    }

    /// The caption under a day count: "days to go", "days ago", or "Today".
    static func dayCaption(_ countdown: Countdown) -> String {
        switch countdown.direction {
        case _ where countdown.isToday: return String(localized: "common.today")
        case .future:
            return abs(countdown.days) == 1
                ? String(localized: "caption.dayToGo")
                : String(localized: "caption.daysToGo")
        case .past:
            return abs(countdown.days) == 1
                ? String(localized: "caption.dayAgo")
                : String(localized: "caption.daysAgo")
        case .present: return String(localized: "common.today")
        }
    }

    /// A short phrase for lists and widgets: "Today", "Tomorrow", "in 12 days", "3 days ago".
    static func relativeDays(_ countdown: Countdown) -> String {
        switch (countdown.direction, countdown.days) {
        case (_, 0): String(localized: "common.today")
        case (.future, 1): String(localized: "common.tomorrow")
        case (.past, 1): String(localized: "common.yesterday")
        case (.past, let days): String(localized: "countdown.relativeDaysAgo \(days)")
        default: String(localized: "common.relativeInDays \(countdown.days)")
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

nonisolated extension Recurrence {
    var name: LocalizedStringResource {
        switch self {
        case .never: "common.never"
        case .daily: "countdown.everyDay"
        case .weekly: "countdown.everyWeek"
        case .monthly: "countdown.everyMonth"
        case .yearly: "common.everyYear"
        }
    }
}

nonisolated extension Countdown {
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
        target.formatted(.shortDate(withTime: !isAllDay))
    }
}
