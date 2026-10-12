import Foundation

/// How often an event comes back, such as a birthday every year.
enum Recurrence: String, CaseIterable, Codable, Identifiable, Sendable {
    case never
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}

/// Shorthands for simple repeats; `RecurrenceRule` has the details.
enum EventSchedule {
    /// The occurrence an event counts towards. See `RecurrenceRule.occurrence(of:onOrAfter:calendar:)`.
    static func occurrence(
        of date: Date,
        recurrence: Recurrence,
        onOrAfter reference: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        RecurrenceRule(frequency: recurrence).occurrence(of: date, onOrAfter: reference, calendar: calendar).date
    }

    /// Which occurrence `occurrence` is in the frequency's unit, the original date being 0 —
    /// the age on a birthday, or the number of a wedding anniversary.
    static func occurrenceNumber(
        of occurrence: Date,
        originalDate: Date,
        recurrence: Recurrence,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let rule = RecurrenceRule(frequency: recurrence)
        let (_, index) = rule.occurrence(of: originalDate, onOrAfter: occurrence, calendar: calendar)
        return rule.occurrenceNumber(index: index)
    }
}

/// All-day events are stored as midnight UTC of their day, so "12 March" stays
/// 12 March on every device and in every time zone — on a trip, or on a Mac
/// synced through iCloud in another country.
enum FloatingDay {
    /// The stored form of the day `date` falls on in `calendar`.
    static func storedDate(forDayOf date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return utc(calendar).date(from: components) ?? date
    }

    /// The start of the stored day in `calendar`'s time zone.
    static func localDate(fromStored stored: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let components = utc(calendar).dateComponents([.era, .year, .month, .day], from: stored)
        return calendar.date(from: components).map(calendar.startOfDay(for:)) ?? stored
    }

    private static func utc(_ calendar: Calendar) -> Calendar {
        var utc = calendar
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return utc
    }
}
