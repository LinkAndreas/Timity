import Foundation

/// An event Timity counts towards or since: every value it has, safe to pass
/// between threads. Screens, widgets, intents and the Watch all work with these;
/// how they are stored is up to the `EventRepository`.
struct EventSnapshot: Identifiable, Hashable, Sendable {
    var id = UUID()
    var title = ""
    /// The moment of the event. For all-day events, midnight UTC of its day — see
    /// `FloatingDay` — so the day is the same in every time zone.
    var date = Date.now
    var isAllDay = false
    var recurrence = Recurrence.never
    var color = EventColor.orange
    var symbolName = EventSymbol.defaultName
    var isPinned = false
    var imageData: Data? = nil
    /// The time zone a timed event happens in, such as a flight landing in Tokyo;
    /// `nil` for the user's own time zone.
    var timeZoneIdentifier: String? = nil
    /// The list the event belongs to, such as "Family" or "Work"; empty for none.
    var listName = ""
    var isArchived = false
    /// For birthdays imported without a year: the date's year is a placeholder,
    /// so no age is shown.
    var isYearUnknown = false
    /// Every how many periods the event repeats, from 1.
    var recurrenceInterval = 1
    var recurrencePattern = RecurrenceRule.Pattern.sameDay
    /// The calendar a yearly all-day event repeats in; `nil` for the user's own.
    var eventCalendar: EventCalendar? = nil
    /// Whether the countdown shows how much of the wait has passed.
    var showsProgress = false
    /// Where progress starts for one-off events; `nil` for when the event was added.
    var progressStart: Date? = nil
    var notes = ""
    /// Minutes before the event to send a reminder; `nil` for none. For all-day
    /// events, minutes before 9:00 on the day.
    var reminderMinutes: Int? = nil
    /// When earlier streaks of a "since" counter began.
    var resetHistory: [Date] = []
    var checklist: [ChecklistItem] = []
    var createdAt = Date.now
    var modifiedAt = Date.now

    var rule: RecurrenceRule {
        RecurrenceRule(
            frequency: recurrence,
            interval: max(1, recurrenceInterval),
            pattern: recurrencePattern,
            calendarIdentifier: recurrence == .yearly ? eventCalendar?.identifier : nil
        )
    }

    var timeZone: TimeZone? {
        isAllDay ? nil : timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    /// The event's date as a moment in `calendar`: all-day events start at local midnight.
    func startDate(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        isAllDay ? FloatingDay.localDate(fromStored: date, calendar: calendar) : date
    }

    /// Stores `localDate` as the event's date, as a day when the event is all-day.
    mutating func setStartDate(_ localDate: Date, calendar: Calendar = .autoupdatingCurrent) {
        date = isAllDay ? FloatingDay.storedDate(forDayOf: localDate, calendar: calendar) : localDate
    }

    /// Starts a "since" counter over from now, keeping the old start in the history.
    mutating func startOver(at now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        resetHistory.append(startDate(in: calendar))
        setStartDate(isAllDay ? calendar.startOfDay(for: now) : now, calendar: calendar)
        modifiedAt = now
    }

    func countdown(at now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Countdown {
        Countdown(
            startDate: startDate(in: calendar),
            isAllDay: isAllDay,
            rule: rule,
            eventTimeZone: timeZone,
            showsOccurrenceNumber: !isYearUnknown,
            progressStart: showsProgress ? progressStart ?? createdAt : nil,
            now: now,
            calendar: calendar
        )
    }
}

extension Countdown {
    /// A countdown for a simple repeat.
    init(startDate: Date, isAllDay: Bool, recurrence: Recurrence, now: Date, calendar: Calendar) {
        self.init(startDate: startDate, isAllDay: isAllDay, rule: RecurrenceRule(frequency: recurrence), now: now, calendar: calendar)
    }
}

/// Where an event stands at a moment: its current occurrence, and how far away it is.
struct Countdown: Hashable, Sendable {
    /// The occurrence counted towards — the event's date, or for a repeating event
    /// its next occurrence (today's for the whole day).
    let target: Date
    let isAllDay: Bool
    let direction: TimeDirection
    /// Calendar days between today and the target's day, never negative.
    let days: Int
    /// The occurrence's number for repeating events, e.g. 30 on a 30th birthday; 0 otherwise.
    let occurrenceNumber: Int
    /// Where a timed event happens, when it's not the user's time zone.
    let eventTimeZone: TimeZone?
    let now: Date
    /// How much of the wait has passed, from 0 to 1, when the event shows progress:
    /// since the previous occurrence for repeating events, since `progressStart` otherwise.
    let progress: Double?

    /// - Parameters:
    ///   - eventTimeZone: Where a timed event happens. Repeats keep its wall-clock
    ///     time there; day counts stay in the user's own calendar.
    ///   - showsOccurrenceNumber: `false` when the original year isn't known.
    ///   - progressStart: Where progress starts for one-off events; progress is
    ///     only worked out when it's given.
    init(
        startDate: Date,
        isAllDay: Bool,
        rule: RecurrenceRule,
        eventTimeZone: TimeZone? = nil,
        showsOccurrenceNumber: Bool = true,
        progressStart: Date? = nil,
        now: Date,
        calendar: Calendar
    ) {
        var eventCalendar = calendar
        if let eventTimeZone { eventCalendar.timeZone = eventTimeZone }
        let (target, index) = rule.occurrence(of: startDate, onOrAfter: now, calendar: eventCalendar)
        let signedDays = DateMath.calendarDays(from: now, to: target, calendar: calendar)
        self.target = target
        self.isAllDay = isAllDay
        self.eventTimeZone = eventTimeZone
        self.now = now
        self.days = abs(signedDays)
        self.occurrenceNumber = showsOccurrenceNumber ? rule.occurrenceNumber(index: index) : 0

        if let progressStart {
            let from = rule.repeats && index > 0
                ? rule.previousOccurrence(before: index, of: startDate, calendar: eventCalendar)
                : progressStart
            let total = target.timeIntervalSince(from)
            progress = total > 0 ? min(max(now.timeIntervalSince(from) / total, 0), 1) : 1
        } else {
            progress = nil
        }
        // An all-day event is "now" for its whole day.
        if isAllDay {
            direction = signedDays < 0 ? .past : signedDays > 0 ? .future : .present
        } else {
            direction = DateMath.direction(of: target, relativeTo: now)
        }
    }

    var isToday: Bool { days == 0 }

    func breakdown(includeWeeks: Bool, calendar: Calendar = .autoupdatingCurrent) -> TimeBreakdown {
        DateMath.breakdown(between: now, and: target, includeWeeks: includeWeeks, calendar: calendar)
    }

    func totals(calendar: Calendar = .autoupdatingCurrent) -> TimeTotals {
        DateMath.totals(between: now, and: target, calendar: calendar)
    }
}

extension Sequence where Element == EventSnapshot {
    /// Events that aren't archived.
    var active: [EventSnapshot] { filter { !$0.isArchived } }

    /// Upcoming events soonest first, then past events most recent first.
    func sortedByCountdown(at now: Date = .now) -> [EventSnapshot] {
        let pairs = map { ($0, $0.countdown(at: now)) }
        let upcoming = pairs.filter { $0.1.direction != .past }.sorted { $0.1.target < $1.1.target }
        let past = pairs.filter { $0.1.direction == .past }.sorted { $0.1.target > $1.1.target }
        return (upcoming + past).map(\.0)
    }

    /// The lists used by any of the events, sorted by name.
    var listNames: [String] {
        Set(map(\.listName).filter { !$0.isEmpty })
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
