import Foundation

/// When a repeating event comes back: how often, every how many periods, on which
/// day of the month, and in which calendar.
///
/// Like Calendar's repeats, the day comes from the event's first date: a first
/// date on Thursday, 16 October can repeat on the 16th, on the third Thursday, or
/// — as it's in the month's last seven days — on the last Thursday.
struct RecurrenceRule: Hashable, Sendable {
    enum Pattern: String, CaseIterable, Identifiable, Sendable {
        /// The same day of the month (and month, for yearly events).
        case sameDay
        /// The same weekday by its number in the month, e.g. the third Thursday.
        case nthWeekday
        /// The month's last occurrence of the same weekday, e.g. the last Friday.
        case lastWeekday
        /// The month's last day that isn't a weekend day — payday. Monthly only.
        case lastWorkingDay

        var id: String { rawValue }
    }

    var frequency: Recurrence
    /// Every how many days, weeks, months or years, from 1.
    var interval: Int = 1
    var pattern: Pattern = .sameDay
    /// For yearly events in another calendar, such as a birthday kept by the
    /// Chinese lunar calendar; `nil` for the user's own calendar.
    var calendarIdentifier: Calendar.Identifier? = nil

    static let never = RecurrenceRule(frequency: .never)

    var repeats: Bool { frequency != .never }

    /// The patterns that make sense for a first date: the last weekday only when
    /// the date is in its month's last week, the last working day only monthly.
    static func patterns(for date: Date, frequency: Recurrence, calendar: Calendar = .autoupdatingCurrent) -> [Pattern] {
        guard frequency == .monthly || frequency == .yearly else { return [.sameDay] }
        var patterns: [Pattern] = [.sameDay, .nthWeekday]
        if isInLastWeek(date, calendar: calendar) { patterns.append(.lastWeekday) }
        if frequency == .monthly { patterns.append(.lastWorkingDay) }
        return patterns
    }

    /// The weekday's number in its month: 3 for the third Thursday.
    static func weekdayOrdinal(of date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        (calendar.component(.day, from: date) - 1) / 7 + 1
    }

    static func isInLastWeek(_ date: Date, calendar: Calendar) -> Bool {
        guard let days = calendar.range(of: .day, in: .month, for: date) else { return false }
        return calendar.component(.day, from: date) > days.count - 7
    }

    // MARK: Occurrences

    /// The occurrence counted towards on `reference`'s day: the first date if it's
    /// still ahead, otherwise the first occurrence on or after that day — so an
    /// occurrence stays current for the whole of its day.
    func occurrence(of start: Date, onOrAfter reference: Date, calendar: Calendar) -> (date: Date, index: Int) {
        guard repeats else { return (start, 0) }
        let today = calendar.startOfDay(for: reference)
        guard start < today else { return (start, 0) }

        var index = estimatedIndex(from: start, to: today, calendar: calendar)
        // The estimate is at most a period or two short; step forward from it.
        var date = occurrence(index, of: start, calendar: calendar)
        var steps = 0
        while date < today, steps < 400 {
            index += 1
            steps += 1
            date = occurrence(index, of: start, calendar: calendar)
        }
        return (date, index)
    }

    /// The occurrence before `index`, or the first date.
    func previousOccurrence(before index: Int, of start: Date, calendar: Calendar) -> Date {
        index > 0 ? occurrence(index - 1, of: start, calendar: calendar) : start
    }

    /// The `index`th occurrence, the first date being 0.
    func occurrence(_ index: Int, of start: Date, calendar base: Calendar) -> Date {
        let calendar = ruleCalendar(base)
        let step = index * max(1, interval)
        switch frequency {
        case .never:
            return start
        case .daily:
            return calendar.date(byAdding: .day, value: step, to: start) ?? start
        case .weekly:
            return calendar.date(byAdding: .day, value: step * 7, to: start) ?? start
        case .monthly, .yearly:
            let component: Calendar.Component = frequency == .monthly ? .month : .year
            if pattern == .sameDay {
                // Adding to the first date keeps its day, falling back to the month's last
                // day when needed (31 January, then 28 February, then 31 March).
                return calendar.date(byAdding: component, value: step, to: start) ?? start
            }
            guard
                let monthStart = calendar.dateInterval(of: .month, for: start)?.start,
                let month = calendar.date(byAdding: component, value: step, to: monthStart),
                let day = day(in: month, matching: start, calendar: calendar)
            else { return start }
            return settingTime(of: start, on: day, calendar: calendar)
        }
    }

    /// The occurrence's number in the frequency's unit, e.g. 30 years on a 30th birthday.
    func occurrenceNumber(index: Int) -> Int {
        index * max(1, interval)
    }

    // MARK: Private

    private func ruleCalendar(_ base: Calendar) -> Calendar {
        guard frequency == .yearly, let calendarIdentifier, calendarIdentifier != base.identifier else { return base }
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = base.timeZone
        calendar.locale = base.locale
        return calendar
    }

    private func estimatedIndex(from start: Date, to today: Date, calendar base: Calendar) -> Int {
        let calendar = ruleCalendar(base)
        let periods: Int
        switch frequency {
        case .never: return 0
        case .daily: periods = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        case .weekly: periods = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) / 7
        case .monthly: periods = calendar.dateComponents([.month], from: start, to: today).month ?? 0
        case .yearly: periods = calendar.dateComponents([.year], from: start, to: today).year ?? 0
        }
        return max(0, periods / max(1, interval) - 1)
    }

    /// The day in `month` the pattern picks, for a first date `start`.
    private func day(in month: Date, matching start: Date, calendar: Calendar) -> Date? {
        guard let days = calendar.range(of: .day, in: .month, for: month),
              let monthStart = calendar.dateInterval(of: .month, for: month)?.start
        else { return nil }
        let dates = days.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        let weekday = calendar.component(.weekday, from: start)

        switch pattern {
        case .sameDay:
            return nil
        case .nthWeekday:
            let matches = dates.filter { calendar.component(.weekday, from: $0) == weekday }
            let ordinal = Self.weekdayOrdinal(of: start, calendar: calendar)
            // A fifth Thursday in a month with only four falls on the last.
            return matches.indices.contains(ordinal - 1) ? matches[ordinal - 1] : matches.last
        case .lastWeekday:
            return dates.last { calendar.component(.weekday, from: $0) == weekday }
        case .lastWorkingDay:
            return dates.last { !calendar.isDateInWeekend($0) }
        }
    }

    private func settingTime(of start: Date, on day: Date, calendar: Calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: start)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
    }
}
