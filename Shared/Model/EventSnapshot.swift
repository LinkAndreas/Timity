import Foundation

/// A copy of an event's values, safe to pass between threads — for widgets,
/// intents and the Watch.
struct EventSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    /// As stored; see `Event.date`.
    let date: Date
    let isAllDay: Bool
    let recurrence: Recurrence
    let color: EventColor
    let symbolName: String
    let isPinned: Bool
    let imageData: Data?
    var timeZoneIdentifier: String? = nil
    var listName: String = ""
    var isArchived: Bool = false
    var isYearUnknown: Bool = false
    var recurrenceInterval: Int = 1
    var recurrencePattern: RecurrenceRule.Pattern = .sameDay
    var eventCalendar: EventCalendar? = nil
    var showsProgress: Bool = false
    /// Where progress starts for one-off events.
    var progressStart: Date? = nil

    var rule: RecurrenceRule {
        RecurrenceRule(
            frequency: recurrence,
            interval: recurrenceInterval,
            pattern: recurrencePattern,
            calendarIdentifier: recurrence == .yearly ? eventCalendar?.identifier : nil
        )
    }

    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
    }

    func startDate(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        isAllDay ? FloatingDay.localDate(fromStored: date, calendar: calendar) : date
    }

    func countdown(at now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Countdown {
        Countdown(
            startDate: startDate(in: calendar),
            isAllDay: isAllDay,
            rule: rule,
            eventTimeZone: timeZone,
            showsOccurrenceNumber: !isYearUnknown,
            progressStart: showsProgress ? progressStart : nil,
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
}
