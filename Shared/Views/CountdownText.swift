import SwiftUI

/// The words around Timity's numbers, localized with proper plurals.
nonisolated enum CountdownText {
    /// The unit's name for `value`, without the number: "day" or "days", in Russian
    /// "день", "дня" or "дней". The String Catalog picks the language's plural form for
    /// the count; the number itself is left to the caller, often styled on its own.
    static func unit(_ unit: TimeUnit, value: Int, locale: Locale? = nil) -> String {
        let count = abs(value)
        let key: String.LocalizationValue = switch unit {
        case .year: "unit.year \(count)"
        case .month: "unit.month \(count)"
        case .week: "unit.week \(count)"
        case .day: "unit.day \(count)"
        case .hour: "unit.hour \(count)"
        case .minute: "unit.minute \(count)"
        case .second: "unit.second \(count)"
        }
        return localized(key, locale: locale)
    }

    /// The unit's name for a decimal `value`, without the number: "1.5 years", «1,5 года».
    /// Decimals take the language's plural form for fractions (English and Russian "other",
    /// French "one" below 2), so round `value` to the digits shown before passing it.
    static func unit(_ unit: TimeUnit, decimal value: Double, locale: Locale? = nil) -> String {
        let amount = abs(value)
        let key: String.LocalizationValue = switch unit {
        case .year: "unit.year \(amount)"
        case .month: "unit.month \(amount)"
        case .week: "unit.week \(amount)"
        case .day: "unit.day \(amount)"
        case .hour: "unit.hour \(amount)"
        case .minute: "unit.minute \(amount)"
        case .second: "unit.second \(amount)"
        }
        return localized(key, locale: locale)
    }

    /// The unit's name with no number to agree with, for a row or field label: "Days".
    static func label(_ unit: TimeUnit, locale: Locale? = nil) -> String {
        let key: String.LocalizationValue = switch unit {
        case .year: "unit.year.label"
        case .month: "unit.month.label"
        case .week: "unit.week.label"
        case .day: "unit.day.label"
        case .hour: "unit.hour.label"
        case .minute: "unit.minute.label"
        case .second: "unit.second.label"
        }
        return localized(key, locale: locale)
    }

    /// The caption under a day count: "days to go", "days ago", or "Today".
    static func dayCaption(_ countdown: Countdown, locale: Locale? = nil) -> String {
        dayCaption(days: countdown.days, direction: countdown.isToday ? .present : countdown.direction, locale: locale)
    }

    /// The caption under `days`, agreeing with it: "1 / day to go", "3 / days ago";
    /// in Russian "21 / день остался", "23 / дня осталось", "25 / дней осталось".
    static func dayCaption(days: Int, direction: TimeDirection, locale: Locale? = nil) -> String {
        let count = abs(days)
        return switch direction {
        case .future: localized("caption.daysToGo \(count)", locale: locale)
        case .past: localized("caption.daysAgo \(count)", locale: locale)
        case .present: localized("common.today", locale: locale)
        }
    }

    /// Looks `key` up in the app's String Catalog: in the app's language, or in `locale`'s
    /// when one is given (tests check the plural forms of several languages this way).
    private static func localized(_ key: String.LocalizationValue, locale: Locale?) -> String {
        guard let locale else { return String(localized: key) }
        return String(localized: LocalizedStringResource(key, locale: locale))
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
        breakdownText(breakdown, includingSeconds: includingSeconds, style: .full)
    }

    /// The whole breakdown in one short line: "2w 6d 11h 56m 30s".
    static func compactBreakdown(_ breakdown: TimeBreakdown, includingSeconds: Bool) -> String {
        breakdownText(breakdown, includingSeconds: includingSeconds, style: .abbreviated)
    }

    private static func breakdownText(_ breakdown: TimeBreakdown, includingSeconds: Bool, style: DateComponentsFormatter.UnitsStyle) -> String {
        var components = DateComponents()
        components.year = breakdown.years
        components.month = breakdown.months
        components.weekOfMonth = breakdown.weeks
        components.day = breakdown.days
        components.hour = breakdown.hours
        components.minute = breakdown.minutes
        if includingSeconds { components.second = breakdown.seconds }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = style
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute, .second]
        return formatter.string(from: components) ?? ""
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
