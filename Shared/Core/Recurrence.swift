import Foundation

/// How often an event comes back, such as a birthday every year.
enum Recurrence: String, CaseIterable, Codable, Identifiable, Sendable {
    case never
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// The parts of the original date every occurrence shares.
    fileprivate var matchingComponents: Set<Calendar.Component> {
        switch self {
        case .never: []
        case .weekly: [.weekday, .hour, .minute, .second]
        case .monthly: [.day, .hour, .minute, .second]
        case .yearly: [.month, .day, .hour, .minute, .second]
        }
    }
}

enum EventSchedule {
    /// The occurrence an event counts towards.
    ///
    /// A one-off event is just its date. A repeating event counts towards its next
    /// occurrence, and today's occurrence stays current for the whole day, so a
    /// birthday reads "Today" until midnight. Occurrences on days a month or year
    /// doesn't have fall on the last day before them: 29 February on 28 February,
    /// the 31st on the 30th.
    static func occurrence(
        of date: Date,
        recurrence: Recurrence,
        onOrAfter reference: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        guard recurrence != .never else { return date }

        let today = calendar.startOfDay(for: reference)
        guard date < today else { return date }

        let components = calendar.dateComponents(recurrence.matchingComponents, from: date)
        return calendar.nextDate(
            after: today.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .previousTimePreservingSmallerComponents,
            direction: .forward
        ) ?? date
    }

    /// Which occurrence `occurrence` is, counting the original date as 0 — the
    /// age on a birthday, or the number of a wedding anniversary.
    static func occurrenceNumber(
        of occurrence: Date,
        originalDate: Date,
        recurrence: Recurrence,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        guard occurrence > originalDate else { return 0 }
        // Counted from the calendar fields rather than elapsed time, so a 29 February
        // anniversary moved to 28 February still counts as a full year.
        let original = calendar.dateComponents([.year, .month], from: originalDate)
        let current = calendar.dateComponents([.year, .month], from: occurrence)
        let years = (current.year ?? 0) - (original.year ?? 0)
        switch recurrence {
        case .never:
            return 0
        case .yearly:
            return years
        case .monthly:
            return years * 12 + (current.month ?? 0) - (original.month ?? 0)
        case .weekly:
            return DateMath.calendarDays(from: originalDate, to: occurrence, calendar: calendar) / 7
        }
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
