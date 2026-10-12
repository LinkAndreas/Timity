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

    func startDate(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        isAllDay ? FloatingDay.localDate(fromStored: date, calendar: calendar) : date
    }

    func countdown(at now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Countdown {
        Countdown(
            startDate: startDate(in: calendar),
            isAllDay: isAllDay,
            recurrence: recurrence,
            now: now,
            calendar: calendar
        )
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
    let now: Date

    init(startDate: Date, isAllDay: Bool, recurrence: Recurrence, now: Date, calendar: Calendar) {
        let target = EventSchedule.occurrence(of: startDate, recurrence: recurrence, onOrAfter: now, calendar: calendar)
        let signedDays = DateMath.calendarDays(from: now, to: target, calendar: calendar)
        self.target = target
        self.isAllDay = isAllDay
        self.now = now
        self.days = abs(signedDays)
        self.occurrenceNumber = EventSchedule.occurrenceNumber(
            of: target,
            originalDate: startDate,
            recurrence: recurrence,
            calendar: calendar
        )
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
    /// Upcoming events soonest first, then past events most recent first.
    func sortedByCountdown(at now: Date = .now) -> [EventSnapshot] {
        let pairs = map { ($0, $0.countdown(at: now)) }
        let upcoming = pairs.filter { $0.1.direction != .past }.sorted { $0.1.target < $1.1.target }
        let past = pairs.filter { $0.1.direction == .past }.sorted { $0.1.target > $1.1.target }
        return (upcoming + past).map(\.0)
    }
}
