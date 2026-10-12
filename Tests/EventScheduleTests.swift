import Foundation
import Testing
@testable import Timity

@Suite("Repeating events")
struct EventScheduleTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("A one-off event is its own date")
    func oneOff() {
        let date = calendar.date(2020, 5, 1, 9, 0)
        let now = calendar.date(2025, 1, 1, 0, 0)
        #expect(EventSchedule.occurrence(of: date, recurrence: .never, onOrAfter: now, calendar: calendar) == date)
    }

    @Test("A future repeating event counts towards its first date")
    func futureStart() {
        let date = calendar.date(2026, 5, 1, 9, 0)
        let now = calendar.date(2025, 1, 1, 0, 0)
        #expect(EventSchedule.occurrence(of: date, recurrence: .yearly, onOrAfter: now, calendar: calendar) == date)
    }

    @Test("A birthday counts towards this year's date")
    func yearly() {
        let birthday = calendar.date(1990, 11, 3, 0, 0)
        let now = calendar.date(2025, 10, 12, 15, 0)
        let next = EventSchedule.occurrence(of: birthday, recurrence: .yearly, onOrAfter: now, calendar: calendar)
        #expect(next == calendar.date(2025, 11, 3, 0, 0))
        #expect(EventSchedule.occurrenceNumber(of: next, originalDate: birthday, recurrence: .yearly, calendar: calendar) == 35)
    }

    @Test("Today's occurrence stays current until midnight")
    func todayStaysCurrent() {
        let birthday = calendar.date(1990, 10, 12, 8, 0)
        let evening = calendar.date(2025, 10, 12, 22, 0)
        #expect(
            EventSchedule.occurrence(of: birthday, recurrence: .yearly, onOrAfter: evening, calendar: calendar)
                == calendar.date(2025, 10, 12, 8, 0)
        )
        let nextMorning = calendar.date(2025, 10, 13, 0, 1)
        #expect(
            EventSchedule.occurrence(of: birthday, recurrence: .yearly, onOrAfter: nextMorning, calendar: calendar)
                == calendar.date(2026, 10, 12, 8, 0)
        )
    }

    @Test("29 February falls on 28 February in common years")
    func leapDay() {
        let birthday = calendar.date(2000, 2, 29, 0, 0)
        let now = calendar.date(2025, 1, 1, 0, 0)
        let next = EventSchedule.occurrence(of: birthday, recurrence: .yearly, onOrAfter: now, calendar: calendar)
        #expect(next == calendar.date(2025, 2, 28, 0, 0))
        #expect(EventSchedule.occurrenceNumber(of: next, originalDate: birthday, recurrence: .yearly, calendar: calendar) == 25)

        let inLeapYear = EventSchedule.occurrence(of: birthday, recurrence: .yearly, onOrAfter: calendar.date(2027, 3, 1, 0, 0), calendar: calendar)
        #expect(inLeapYear == calendar.date(2028, 2, 29, 0, 0))
    }

    @Test("The 31st falls on the last day of shorter months")
    func monthlyMonthEnd() {
        let date = calendar.date(2025, 1, 31, 18, 0)
        let now = calendar.date(2025, 4, 2, 0, 0)
        let next = EventSchedule.occurrence(of: date, recurrence: .monthly, onOrAfter: now, calendar: calendar)
        #expect(next == calendar.date(2025, 4, 30, 18, 0))
        #expect(EventSchedule.occurrenceNumber(of: next, originalDate: date, recurrence: .monthly, calendar: calendar) == 3)
    }

    @Test("Weekly events come back on the same weekday")
    func weekly() {
        let date = calendar.date(2025, 10, 1, 19, 30) // a Wednesday
        let now = calendar.date(2025, 10, 12, 10, 0) // a Sunday
        let next = EventSchedule.occurrence(of: date, recurrence: .weekly, onOrAfter: now, calendar: calendar)
        #expect(next == calendar.date(2025, 10, 15, 19, 30))
        #expect(EventSchedule.occurrenceNumber(of: next, originalDate: date, recurrence: .weekly, calendar: calendar) == 2)
    }

    @Test("All-day events keep their day in every time zone")
    func floatingDay() {
        let tokyo = Calendar.fixture(timeZone: "Asia/Tokyo")
        let losAngeles = Calendar.fixture(timeZone: "America/Los_Angeles")

        // Early morning on 12 March in Tokyo is still 11 March in Los Angeles.
        let pickedInTokyo = tokyo.date(2025, 3, 12, 1, 0)
        let stored = FloatingDay.storedDate(forDayOf: pickedInTokyo, calendar: tokyo)
        let shownInLosAngeles = FloatingDay.localDate(fromStored: stored, calendar: losAngeles)

        #expect(losAngeles.dateComponents([.year, .month, .day, .hour], from: shownInLosAngeles)
            == DateComponents(year: 2025, month: 3, day: 12, hour: 0))
    }
}
