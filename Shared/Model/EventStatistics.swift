import Foundation

/// A year in review: what the user counted towards and since in a calendar year.
struct EventStatistics: Equatable, Sendable {
    /// Every event, archived ones included.
    let totalEvents: Int
    /// Occurrences that fall in the year, repeats counted each time.
    let occurrencesInYear: Int
    /// Occurrences in the year that have already happened.
    let reachedInYear: Int
    /// The month with the most occurrences in the year (1–12) and how many it has.
    let busiestMonth: (month: Int, count: Int)?
    /// The event that has been running the longest, and since when.
    let oldestEvent: (title: String, date: Date)?
    /// Occurrences per month, January first.
    let occurrencesPerMonth: [Int]

    static func == (lhs: EventStatistics, rhs: EventStatistics) -> Bool {
        lhs.totalEvents == rhs.totalEvents
            && lhs.occurrencesInYear == rhs.occurrencesInYear
            && lhs.reachedInYear == rhs.reachedInYear
            && lhs.busiestMonth?.month == rhs.busiestMonth?.month
            && lhs.busiestMonth?.count == rhs.busiestMonth?.count
            && lhs.occurrencesPerMonth == rhs.occurrencesPerMonth
    }

    init(events: [EventSnapshot], year: Int, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        totalEvents = events.count
        guard
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)
        else {
            occurrencesInYear = 0
            reachedInYear = 0
            busiestMonth = nil
            oldestEvent = nil
            occurrencesPerMonth = Array(repeating: 0, count: 12)
            return
        }

        var dates: [Date] = []
        for event in events {
            let start = event.startDate(in: calendar)
            let rule = event.rule
            guard rule.repeats else {
                if start >= yearStart, start < yearEnd { dates.append(start) }
                continue
            }
            // Every occurrence in the year, from the first one on or after its start.
            var (date, index) = rule.occurrence(of: start, onOrAfter: yearStart, calendar: calendar)
            var guardSteps = 0
            while date < yearEnd, guardSteps < 400 {
                if date >= yearStart { dates.append(date) }
                index += 1
                guardSteps += 1
                date = rule.occurrence(index, of: start, calendar: calendar)
            }
        }

        var perMonth = Array(repeating: 0, count: 12)
        for date in dates {
            perMonth[calendar.component(.month, from: date) - 1] += 1
        }
        occurrencesPerMonth = perMonth
        occurrencesInYear = dates.count
        reachedInYear = dates.filter { $0 <= now }.count
        if let best = perMonth.enumerated().max(by: { $0.element < $1.element }), best.element > 0 {
            busiestMonth = (best.offset + 1, best.element)
        } else {
            busiestMonth = nil
        }
        oldestEvent = events
            .map { ($0.title, $0.startDate(in: calendar)) }
            .filter { $0.1 <= now }
            .min { $0.1 < $1.1 }
    }
}
