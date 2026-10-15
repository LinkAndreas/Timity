import Foundation

/// Every date and time calculation in Timity.
///
/// All results follow the calendar rather than fixed lengths: a day across a daylight
/// saving change is still one day, a month is the length of that month, and a span
/// is always measured from its earlier moment, so "3 months ago" and "in 3 months"
/// agree. The calendar is passed in so tests can pin the time zone and locale.
enum DateMath {
    static func direction(of date: Date, relativeTo reference: Date) -> TimeDirection {
        if date < reference { return .past }
        if date > reference { return .future }
        return .present
    }

    /// The span between two moments as calendar parts, measured from the earlier one.
    /// With `includeWeeks`, whole weeks are taken out of the days.
    static func breakdown(
        between first: Date,
        and second: Date,
        includeWeeks: Bool = true,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TimeBreakdown {
        let (start, end) = ordered(first, second)
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: start,
            to: end
        )
        let days = components.day ?? 0
        return TimeBreakdown(
            years: components.year ?? 0,
            months: components.month ?? 0,
            weeks: includeWeeks ? days / 7 : 0,
            days: includeWeeks ? days % 7 : days,
            hours: components.hour ?? 0,
            minutes: components.minute ?? 0,
            seconds: components.second ?? 0
        )
    }

    /// The span between two moments in each unit on its own, with fractions.
    ///
    /// Hours, minutes and seconds are elapsed time. Days, weeks, months and years
    /// count calendar units, with the remainder as a fraction of the unit it falls
    /// in — so a month is never assumed to be 30.44 days.
    static func totals(
        between first: Date,
        and second: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TimeTotals {
        let (start, end) = ordered(first, second)
        let seconds = end.timeIntervalSince(start)
        let days = fractionalCount(of: .day, from: start, to: end, calendar: calendar)
        return TimeTotals(
            years: fractionalCount(of: .year, from: start, to: end, calendar: calendar),
            months: fractionalCount(of: .month, from: start, to: end, calendar: calendar),
            weeks: days / 7,
            days: days,
            hours: seconds / 3600,
            minutes: seconds / 60,
            seconds: seconds.rounded(.down)
        )
    }

    /// Calendar days from one date's day to another's: 1 for tomorrow at any time,
    /// -1 for yesterday. Negative when `date` is before `reference`.
    static func calendarDays(
        from reference: Date,
        to date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let start = calendar.startOfDay(for: reference)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// The number of working days (days that aren't weekend days in the calendar's
    /// locale) from the first date's day up to the second's. The last day counts
    /// only when `includingLastDay` is set.
    static func weekdays(
        between first: Date,
        and second: Date,
        includingLastDay: Bool = false,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let (start, end) = ordered(calendar.startOfDay(for: first), calendar.startOfDay(for: second))
        var dayCount = calendarDays(from: start, to: end, calendar: calendar)
        if includingLastDay { dayCount += 1 }
        guard dayCount > 0 else { return 0 }

        func isWorkday(_ offset: Int) -> Bool {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return false }
            return !calendar.isDateInWeekend(day)
        }

        let workdaysPerWeek = (0..<7).filter(isWorkday).count
        let fullWeeks = dayCount / 7
        let remainder = (fullWeeks * 7..<dayCount).filter(isWorkday).count
        return fullWeeks * workdaysPerWeek + remainder
    }

    /// `date` moved forwards or backwards by the parts of `offset`, largest part first,
    /// so adding a month to 31 January gives the last day of February.
    static func date(
        _ date: Date,
        movedBy offset: TimeBreakdown,
        backwards: Bool,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let sign = backwards ? -1 : 1
        var components = DateComponents()
        components.year = sign * offset.years
        components.month = sign * offset.months
        // Weeks are always seven days; `weekOfYear` would depend on the calendar's week rules.
        components.day = sign * (offset.weeks * 7 + offset.days)
        components.hour = sign * offset.hours
        components.minute = sign * offset.minutes
        components.second = sign * offset.seconds
        return calendar.date(byAdding: components, to: date)
    }

    /// `day`'s date at the hour and minute of `time`, e.g. when a calculator starts
    /// including times; seconds are dropped.
    static func date(_ day: Date, atTimeOf time: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: day) ?? day
    }

    /// The ISO-style week number the calendar gives `date`, e.g. 42.
    static func weekOfYear(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    /// How many weeks the week-based year has in `calendar`: 52 or 53.
    static func weeksInYear(_ yearForWeekOfYear: Int, calendar: Calendar = .autoupdatingCurrent) -> Int {
        guard
            let midyear = calendar.date(from: DateComponents(year: yearForWeekOfYear, month: 7, day: 1)),
            let weeks = calendar.range(of: .weekOfYear, in: .yearForWeekOfYear, for: midyear)
        else { return 52 }
        return weeks.count
    }

    /// The days of week `week` in week-based year `year`, starting on the calendar's first weekday.
    static func week(_ week: Int, of year: Int, calendar: Calendar = .autoupdatingCurrent) -> DateInterval? {
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = calendar.firstWeekday
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.dateInterval(of: .weekOfYear, for: date)
    }

    /// The day of the year, 1 for the first day.
    static func dayOfYear(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// How far `date` is through its year, from 0 to 1.
    static func progressThroughYear(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Double {
        guard let year = calendar.dateInterval(of: .year, for: date) else { return 0 }
        return date.timeIntervalSince(year.start) / year.duration
    }

    // MARK: Private

    private static func ordered(_ first: Date, _ second: Date) -> (Date, Date) {
        first <= second ? (first, second) : (second, first)
    }

    /// Whole units from `start` to `end`, plus the fraction of the next unit that has passed.
    private static func fractionalCount(
        of component: Calendar.Component,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> Double {
        let whole = calendar.dateComponents([component], from: start, to: end).value(for: component) ?? 0
        guard
            let unitStart = calendar.date(byAdding: component, value: whole, to: start),
            let unitEnd = calendar.date(byAdding: component, value: whole + 1, to: start),
            unitEnd > unitStart
        else { return Double(whole) }

        let fraction = end.timeIntervalSince(unitStart) / unitEnd.timeIntervalSince(unitStart)
        return Double(whole) + min(max(fraction, 0), 1)
    }
}
