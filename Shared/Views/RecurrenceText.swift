import Foundation

/// Repeats in words: "Every 2 Weeks", "On the 3rd Thursday", "Chinese Calendar".
enum RecurrenceText {
    /// The whole rule in one line, e.g. "Every Month · On the Last Working Day".
    static func summary(_ rule: RecurrenceRule, start: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        guard rule.repeats else { return String(localized: "common.never") }
        var parts = [frequency(rule)]
        if rule.frequency == .monthly || rule.frequency == .yearly, rule.pattern != .sameDay {
            parts.append(pattern(rule.pattern, frequency: rule.frequency, start: start, calendar: calendar))
        }
        if rule.frequency == .yearly, let identifier = rule.calendarIdentifier,
           let kind = EventCalendar.allCases.first(where: { $0.identifier == identifier }) {
            parts.append(String(localized: kind.name))
        }
        return parts.joined(separator: " · ")
    }

    /// "Every Week" or "Every 2 Weeks".
    static func frequency(_ rule: RecurrenceRule) -> String {
        let interval = max(1, rule.interval)
        guard interval > 1 else { return String(localized: rule.frequency.name) }
        switch rule.frequency {
        case .never: return String(localized: "common.never")
        case .daily: return String(localized: "recurrence.everyDays \(interval)")
        case .weekly: return String(localized: "recurrence.everyWeeks \(interval)")
        case .monthly: return String(localized: "recurrence.everyMonths \(interval)")
        case .yearly: return String(localized: "recurrence.everyYears \(interval)")
        }
    }

    /// The day a pattern picks for `start`, e.g. "On the 3rd Thursday of November".
    static func pattern(
        _ pattern: RecurrenceRule.Pattern,
        frequency: Recurrence,
        start: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let weekday = calendar.weekdaySymbols[calendar.component(.weekday, from: start) - 1]
        let month = calendar.monthSymbols[calendar.component(.month, from: start) - 1]
        let isYearly = frequency == .yearly
        switch pattern {
        case .sameDay:
            return isYearly
                ? String(localized: "recurrence.on \(start.formatted(.dateTime.day().month(.wide)))")
                : String(localized: "recurrence.onThe \(ordinal(calendar.component(.day, from: start)))")
        case .nthWeekday:
            let number = ordinal(RecurrenceRule.weekdayOrdinal(of: start, calendar: calendar))
            return isYearly
                ? String(localized: "recurrence.onTheOf \(number) \(weekday) \(month)")
                : String(localized: "recurrence.onThe2 \(number) \(weekday)")
        case .lastWeekday:
            return isYearly
                ? String(localized: "recurrence.onTheLastOf \(weekday) \(month)")
                : String(localized: "recurrence.onTheLast \(weekday)")
        case .lastWorkingDay:
            return String(localized: "recurrence.onTheLastWorkingDay")
        }
    }

    private static func ordinal(_ number: Int) -> String {
        CountdownText.ordinal(number)
    }
}

extension EventCalendar {
    var name: LocalizedStringResource {
        switch self {
        case .chinese: "recurrence.chineseCalendar"
        case .hebrew: "recurrence.hebrewCalendar"
        case .islamic: "recurrence.islamicCalendar"
        case .persian: "recurrence.persianCalendar"
        case .indian: "recurrence.indianNationalCalendar"
        }
    }

    /// `date` as this calendar writes it, e.g. the lunar month and day.
    func formatted(_ date: Date, base: Calendar = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(basedOn: base)
        formatter.locale = base.locale ?? .autoupdatingCurrent
        formatter.timeZone = base.timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
