import Foundation
import Testing
@testable import Timity

@Suite("Date math")
struct DateMathTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("A day across the spring daylight saving change is still one day")
    func calendarDaysAcrossSpringForward() {
        // 30 March 2025 has 23 hours in Berlin.
        let start = calendar.date(2025, 3, 30, 0, 0)
        let end = calendar.date(2025, 3, 31, 0, 0)
        #expect(DateMath.calendarDays(from: start, to: end, calendar: calendar) == 1)
    }

    @Test("Days to an event count calendar days, not 24-hour blocks")
    func calendarDaysIgnoreTimeOfDay() {
        let now = calendar.date(2025, 10, 12, 23, 30)
        let tomorrowMorning = calendar.date(2025, 10, 13, 0, 15)
        #expect(DateMath.calendarDays(from: now, to: tomorrowMorning, calendar: calendar) == 1)
        #expect(DateMath.calendarDays(from: tomorrowMorning, to: now, calendar: calendar) == -1)
    }

    @Test("Days across the autumn change, which has 25 hours")
    func calendarDaysAcrossFallBack() {
        let start = calendar.date(2025, 10, 20, 12, 0)
        let end = calendar.date(2025, 10, 30, 12, 0)
        #expect(DateMath.calendarDays(from: start, to: end, calendar: calendar) == 10)
    }

    @Test("A span reads the same in both directions")
    func breakdownIsSymmetric() {
        let first = calendar.date(2024, 1, 31, 10, 0)
        let second = calendar.date(2025, 3, 1, 8, 30)
        #expect(
            DateMath.breakdown(between: first, and: second, calendar: calendar)
                == DateMath.breakdown(between: second, and: first, calendar: calendar)
        )
    }

    @Test("Weeks are taken out of the days")
    func breakdownWithWeeks() {
        let start = calendar.date(2025, 1, 1, 0, 0)
        let end = calendar.date(2025, 1, 18, 5, 6, 7)
        let breakdown = DateMath.breakdown(between: start, and: end, calendar: calendar)
        #expect(breakdown == TimeBreakdown(weeks: 2, days: 3, hours: 5, minutes: 6, seconds: 7))

        let withoutWeeks = DateMath.breakdown(between: start, and: end, includeWeeks: false, calendar: calendar)
        #expect(withoutWeeks.weeks == 0)
        #expect(withoutWeeks.days == 17)
    }

    @Test("A breakdown across daylight saving keeps whole days")
    func breakdownAcrossDaylightSaving() {
        let start = calendar.date(2025, 3, 29, 12, 0)
        let end = calendar.date(2025, 3, 31, 12, 0)
        let breakdown = DateMath.breakdown(between: start, and: end, calendar: calendar)
        #expect(breakdown == TimeBreakdown(days: 2))
    }

    @Test("Parts leave out zeros but always show seconds when asked")
    func parts() {
        let breakdown = TimeBreakdown(years: 1, days: 2, seconds: 0)
        #expect(breakdown.parts(includingSeconds: true).map(\.unit) == [.year, .day, .second])
        #expect(breakdown.parts(includingSeconds: false).map(\.unit) == [.year, .day])
    }

    @Test("Totals use real month lengths")
    func totalsMonths() {
        let totals = DateMath.totals(
            between: calendar.date(2025, 2, 1, 0, 0),
            and: calendar.date(2025, 2, 15, 0, 0),
            calendar: calendar
        )
        #expect(abs(totals.months - 0.5) < 0.0001)
        #expect(abs(totals.days - 14) < 0.0001)
        #expect(abs(totals.weeks - 2) < 0.0001)
    }

    @Test("Totals over half a year")
    func totalsYears() {
        let totals = DateMath.totals(
            between: calendar.date(2025, 1, 1, 0, 0),
            and: calendar.date(2025, 7, 1, 0, 0),
            calendar: calendar
        )
        #expect(abs(totals.months - 6) < 0.0001)
        #expect(totals.years > 0.49 && totals.years < 0.5)
    }

    @Test("Hours across the spring change are elapsed hours")
    func totalsHoursAcrossDaylightSaving() {
        let totals = DateMath.totals(
            between: calendar.date(2025, 3, 30, 0, 0),
            and: calendar.date(2025, 3, 31, 0, 0),
            calendar: calendar
        )
        #expect(totals.hours == 23)
        #expect(abs(totals.days - 1) < 0.0001)
    }

    @Test("Working days skip weekends")
    func weekdays() {
        let monday = calendar.date(2025, 10, 13, 9, 0)
        let nextMonday = calendar.date(2025, 10, 20, 9, 0)
        #expect(DateMath.weekdays(between: monday, and: nextMonday, calendar: calendar) == 5)
        #expect(DateMath.weekdays(between: monday, and: nextMonday, includingLastDay: true, calendar: calendar) == 6)
        #expect(DateMath.weekdays(between: nextMonday, and: monday, calendar: calendar) == 5)

        let saturday = calendar.date(2025, 10, 18, 0, 0)
        let sunday = calendar.date(2025, 10, 19, 0, 0)
        #expect(DateMath.weekdays(between: saturday, and: sunday, includingLastDay: true, calendar: calendar) == 0)
    }

    @Test("Working days over many years")
    func weekdaysLongSpan() {
        let start = calendar.date(2000, 1, 3, 0, 0) // a Monday
        let end = calendar.date(2000, 1, 3 + 7 * 520, 0, 0) // 520 weeks later
        #expect(DateMath.weekdays(between: start, and: end, calendar: calendar) == 2600)
    }

    @Test("Adding a month to 31 January gives the end of February")
    func addMonthClampsToMonthEnd() {
        let start = calendar.date(2025, 1, 31, 9, 0)
        let result = DateMath.date(start, movedBy: TimeBreakdown(months: 1), backwards: false, calendar: calendar)
        #expect(result == calendar.date(2025, 2, 28, 9, 0))
    }

    @Test("Weeks move by seven days")
    func addWeeks() {
        let start = calendar.date(2025, 12, 29, 9, 0)
        let result = DateMath.date(start, movedBy: TimeBreakdown(weeks: 2, days: 1), backwards: false, calendar: calendar)
        #expect(result == calendar.date(2026, 1, 13, 9, 0))
    }

    @Test("Subtracting moves backwards")
    func subtract() {
        let start = calendar.date(2024, 2, 29, 12, 0)
        let result = DateMath.date(start, movedBy: TimeBreakdown(years: 1, hours: 2), backwards: true, calendar: calendar)
        #expect(result == calendar.date(2023, 2, 28, 10, 0))
    }

    @Test("Adding a day across daylight saving keeps the time of day")
    func addDayAcrossDaylightSaving() {
        let start = calendar.date(2025, 3, 29, 12, 0)
        let result = DateMath.date(start, movedBy: TimeBreakdown(days: 1), backwards: false, calendar: calendar)
        #expect(result == calendar.date(2025, 3, 30, 12, 0))
    }

    @Test("Week and day of the year")
    func weekAndDayOfYear() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let date = calendar.date(2025, 12, 31, 12, 0)
        #expect(DateMath.weekOfYear(date, calendar: iso) == 1)
        #expect(DateMath.dayOfYear(date, calendar: calendar) == 365)
    }

    @Test("A day takes the time of another moment, without its seconds")
    func dayAtTimeOf() {
        let day = calendar.date(2025, 10, 20, 0, 0)
        let time = calendar.date(2026, 1, 5, 14, 35, 42)
        #expect(DateMath.date(day, atTimeOf: time, calendar: calendar) == calendar.date(2025, 10, 20, 14, 35))
    }

    @Test("The time between two moments with times counts the hours that really pass")
    func durationWithTimesAcrossSpringForward() {
        // From 22:00 to 04:00 the night the clocks go forward in Berlin is five hours.
        let start = calendar.date(2025, 3, 29, 22, 0)
        let end = calendar.date(2025, 3, 30, 4, 0)
        let breakdown = DateMath.breakdown(between: start, and: end, calendar: calendar)
        #expect(breakdown == TimeBreakdown(hours: 5))
        #expect(DateMath.totals(between: start, and: end, calendar: calendar).hours == 5)
    }
}

extension Calendar {
    static func fixture(timeZone identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

@Suite("Week numbers")
struct WeekNumberTests {
    @Test("ISO years have 52 or 53 weeks")
    func isoWeeksInYear() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(identifier: "Europe/Berlin")!
        #expect(DateMath.weeksInYear(2020, calendar: iso) == 53)
        #expect(DateMath.weeksInYear(2025, calendar: iso) == 52)
        #expect(DateMath.weeksInYear(2026, calendar: iso) == 53)
    }

    @Test("US weeks start on Sunday and the week of 1 January is week 1")
    func usWeeks() {
        var us = Calendar(identifier: .gregorian)
        us.timeZone = TimeZone(identifier: "America/New_York")!
        us.firstWeekday = 1
        us.minimumDaysInFirstWeek = 1
        let interval = DateMath.week(1, of: 2022, calendar: us)!
        // 1 January 2022 was a Saturday, so week 1 started on Sunday, 26 December 2021.
        #expect(us.dateComponents([.year, .month, .day], from: interval.start) == DateComponents(year: 2021, month: 12, day: 26))
        #expect(DateMath.weeksInYear(2022, calendar: us) == 53)
    }

    @Test("ISO week 1 of 2026 starts on Monday, 29 December 2025")
    func isoWeekStart() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let interval = DateMath.week(1, of: 2026, calendar: iso)!
        #expect(iso.dateComponents([.year, .month, .day], from: interval.start) == DateComponents(year: 2025, month: 12, day: 29))
        #expect(interval.duration == 7 * 86_400)
    }
}
