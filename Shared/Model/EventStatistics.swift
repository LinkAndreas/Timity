import Foundation

/// A year in review: what the user counted towards and since in a calendar year.
nonisolated struct EventStatistics: Equatable, Sendable {
    /// One time an event falls in the year.
    nonisolated struct Moment: Equatable, Sendable {
        let eventID: UUID
        let date: Date
    }

    /// Every time an event falls in the year, repeats counted each time, earliest first.
    let moments: [Moment]
    /// Occurrences in the year that have already happened.
    let reachedInYear: Int
    /// The month with the most occurrences in the year (1–12) and how many it has.
    let busiestMonth: (month: Int, count: Int)?
    /// Occurrences per month, January first.
    let occurrencesPerMonth: [Int]

    /// Occurrences that fall in the year, repeats counted each time.
    var occurrencesInYear: Int { moments.count }

    /// Occurrences in the year still to come.
    var aheadInYear: Int { moments.count - reachedInYear }

    static func == (lhs: EventStatistics, rhs: EventStatistics) -> Bool {
        lhs.moments == rhs.moments
            && lhs.reachedInYear == rhs.reachedInYear
            && lhs.busiestMonth?.month == rhs.busiestMonth?.month
            && lhs.busiestMonth?.count == rhs.busiestMonth?.count
            && lhs.occurrencesPerMonth == rhs.occurrencesPerMonth
    }

    init(events: [EventSnapshot], year: Int, now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        guard
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)
        else {
            moments = []
            reachedInYear = 0
            busiestMonth = nil
            occurrencesPerMonth = Array(repeating: 0, count: 12)
            return
        }

        var moments: [Moment] = []
        for event in events {
            let start = event.startDate(in: calendar)
            let rule = event.rule
            guard rule.repeats else {
                if start >= yearStart, start < yearEnd { moments.append(Moment(eventID: event.id, date: start)) }
                continue
            }
            // Every occurrence in the year, from the first one on or after its start.
            var (date, index) = rule.occurrence(of: start, onOrAfter: yearStart, calendar: calendar)
            var guardSteps = 0
            while date < yearEnd, guardSteps < 400 {
                if date >= yearStart { moments.append(Moment(eventID: event.id, date: date)) }
                index += 1
                guardSteps += 1
                date = rule.occurrence(index, of: start, calendar: calendar)
            }
        }
        moments.sort { $0.date < $1.date }

        var perMonth = Array(repeating: 0, count: 12)
        for moment in moments {
            perMonth[calendar.component(.month, from: moment.date) - 1] += 1
        }
        self.moments = moments
        occurrencesPerMonth = perMonth
        reachedInYear = moments.filter { $0.date <= now }.count
        if let best = perMonth.enumerated().max(by: { $0.element < $1.element }), best.element > 0 {
            busiestMonth = (best.offset + 1, best.element)
        } else {
            busiestMonth = nil
        }
    }
}
