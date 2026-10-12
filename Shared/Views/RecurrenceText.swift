import Foundation

/// Repeats in words: "Every 2 Weeks", "On the 3rd Thursday", "Chinese Calendar".
enum RecurrenceText {
    /// The whole rule in one line, e.g. "Every Month · On the Last Working Day".
    static func summary(_ rule: RecurrenceRule, start: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        guard rule.repeats else { return String(localized: "Never") }
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
        case .never: return String(localized: "Never")
        case .daily: return String(localized: "Every \(interval) Days")
        case .weekly: return String(localized: "Every \(interval) Weeks")
        case .monthly: return String(localized: "Every \(interval) Months")
        case .yearly: return String(localized: "Every \(interval) Years")
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
                ? String(localized: "On \(start.formatted(.dateTime.day().month(.wide)))")
                : String(localized: "On the \(ordinal(calendar.component(.day, from: start)))")
        case .nthWeekday:
            let number = ordinal(RecurrenceRule.weekdayOrdinal(of: start, calendar: calendar))
            return isYearly
                ? String(localized: "On the \(number) \(weekday) of \(month)")
                : String(localized: "On the \(number) \(weekday)")
        case .lastWeekday:
            return isYearly
                ? String(localized: "On the Last \(weekday) of \(month)")
                : String(localized: "On the Last \(weekday)")
        case .lastWorkingDay:
            return String(localized: "On the Last Working Day")
        }
    }

    private static func ordinal(_ number: Int) -> String {
        CountdownText.ordinal(number)
    }
}

extension EventCalendar {
    var name: LocalizedStringResource {
        switch self {
        case .chinese: "Chinese Calendar"
        case .hebrew: "Hebrew Calendar"
        case .islamic: "Islamic Calendar"
        case .persian: "Persian Calendar"
        case .indian: "Indian National Calendar"
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
