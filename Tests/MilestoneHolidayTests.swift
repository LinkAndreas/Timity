import Foundation
import Testing
@testable import Timity

@Suite("Milestones")
struct MilestoneTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("10,000 days after a birth date")
    func tenThousandDays() {
        let birth = calendar.date(2000, 1, 1, 0, 0)
        let milestone = Milestones.all(since: birth, calendar: calendar).first { $0.unit == .day && $0.value == 10_000 }
        #expect(milestone?.date == calendar.date(2027, 5, 19, 0, 0))
    }

    @Test("A billion seconds is elapsed time")
    func billionSeconds() {
        let start = calendar.date(2000, 1, 1, 0, 0)
        let milestone = Milestones.all(since: start, calendar: calendar).first { $0.unit == .second && $0.value == 1_000_000_000 }
        #expect(milestone?.date == start.addingTimeInterval(1_000_000_000))
    }

    @Test("Upcoming milestones are after now and in order")
    func upcoming() {
        let start = calendar.date(2020, 6, 1, 0, 0)
        let now = calendar.date(2025, 10, 12, 0, 0)
        let next = Milestones.upcoming(since: start, after: now, limit: 5, calendar: calendar)
        #expect(next.count == 5)
        #expect(next.allSatisfy { $0.date > now })
        #expect(next.map(\.date) == next.map(\.date).sorted())
    }

    @Test("Future events have no milestones yet")
    func futureStart() {
        let start = calendar.date(2030, 1, 1, 0, 0)
        #expect(Milestones.upcoming(since: start, after: calendar.date(2025, 1, 1, 0, 0), calendar: calendar).isEmpty)
    }
}

@Suite("Public holidays")
struct HolidayTests {
    @Test("Easter Sunday", arguments: [
        (2024, 3, 31), (2025, 4, 20), (2026, 4, 5), (2038, 4, 25), (1961, 4, 2),
    ])
    func easter(year: Int, month: Int, day: Int) {
        #expect(Holidays.easterSunday(year) == DateComponents(year: year, month: month, day: day))
    }

    @Test("German holidays in 2025")
    func germany() {
        let days = Set(HolidayRegion.germany.holidays(in: 2025))
        #expect(days.contains(DateComponents(year: 2025, month: 4, day: 18))) // Good Friday
        #expect(days.contains(DateComponents(year: 2025, month: 5, day: 29))) // Ascension
        #expect(days.contains(DateComponents(year: 2025, month: 6, day: 9)))  // Whit Monday
        #expect(days.count == 9)
    }

    @Test("US federal holidays in 2026, with observed days")
    func unitedStates() {
        let days = Set(HolidayRegion.unitedStates.holidays(in: 2026))
        #expect(days.contains(DateComponents(year: 2026, month: 1, day: 19)))  // MLK Day
        #expect(days.contains(DateComponents(year: 2026, month: 5, day: 25)))  // Memorial Day
        #expect(days.contains(DateComponents(year: 2026, month: 7, day: 3)))   // 4 July is a Saturday
        #expect(days.contains(DateComponents(year: 2026, month: 11, day: 26))) // Thanksgiving
    }

    @Test("UK Christmas substitutes in 2027")
    func unitedKingdom() {
        // 25 December 2027 is a Saturday, the 26th a Sunday.
        let days = Set(HolidayRegion.unitedKingdom.holidays(in: 2027))
        #expect(days.contains(DateComponents(year: 2027, month: 12, day: 27)))
        #expect(days.contains(DateComponents(year: 2027, month: 12, day: 28)))
    }

    @Test("Working days leave out holidays")
    func workingDays() {
        let calendar = Calendar.fixture(timeZone: "Europe/Berlin")
        // Easter week 2025: Monday 14 April to Monday 21 April has Good Friday off.
        let start = calendar.date(2025, 4, 14, 0, 0)
        let end = calendar.date(2025, 4, 21, 0, 0)
        #expect(DateMath.workingDays(between: start, and: end, region: nil, calendar: calendar) == 5)
        #expect(DateMath.workingDays(between: start, and: end, region: .germany, calendar: calendar) == 4)
        // Including Easter Monday as the last day adds nothing.
        #expect(DateMath.workingDays(between: start, and: end, region: .germany, includingLastDay: true, calendar: calendar) == 4)
    }
}

@Suite("Life in weeks")
struct LifeInWeeksTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("Weeks lived and the current week")
    func weeks() {
        let life = LifeInWeeks(birth: calendar.date(1990, 3, 1, 0, 0), now: calendar.date(2025, 3, 20, 0, 0), calendar: calendar)
        #expect(life.completedYears == 35)
        #expect(life.weeksIntoYear == 2)
        #expect(life.isLived(row: 34, column: 51))
        #expect(life.isLived(row: 35, column: 1))
        #expect(life.isCurrent(row: 35, column: 2))
        #expect(!life.isLived(row: 35, column: 2))
        #expect(life.weeksLived == DateMath.calendarDays(from: calendar.date(1990, 3, 1, 0, 0), to: calendar.date(2025, 3, 20, 0, 0), calendar: calendar) / 7)
        // The week it is now comes after the whole ones lived.
        #expect(life.currentWeek == life.weeksLived + 1)
    }
}
