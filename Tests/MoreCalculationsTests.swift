import Foundation
import Testing
@testable import Timity

@Suite("Working days")
struct WorkingDayTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("Five working days after Friday, 11 April 2025, skip Easter in Germany")
    func addAcrossEaster() {
        let start = calendar.date(2025, 4, 11, 9, 0)
        #expect(DateMath.date(start, addingWorkingDays: 5, region: .germany, calendar: calendar) == calendar.date(2025, 4, 22, 9, 0))
        #expect(DateMath.date(start, addingWorkingDays: 5, region: nil, calendar: calendar) == calendar.date(2025, 4, 18, 9, 0))
    }

    @Test("Backwards")
    func subtract() {
        let start = calendar.date(2025, 10, 13, 9, 0) // a Monday
        #expect(DateMath.date(start, addingWorkingDays: -1, region: nil, calendar: calendar) == calendar.date(2025, 10, 10, 9, 0))
    }

    @Test("Holidays have names")
    func names() {
        let holidays = HolidayRegion.germany.namedHolidays(in: 2025)
        #expect(holidays.first { $0.name == "Tag der Deutschen Einheit" }?.date == DateComponents(year: 2025, month: 10, day: 3))
    }
}

@Suite("Moon and seasons")
struct AstronomyTests {
    private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.fixture(timeZone: "UTC").date(year, month, day, hour, minute)
    }

    private func expectNear(_ date: Date, _ expected: Date, minutes: Double) {
        #expect(abs(date.timeIntervalSince(expected)) <= minutes * 60, "Got \(date), expected \(expected)")
    }

    @Test("Phases in October 2024")
    func phases() {
        let start = utc(2024, 9, 25, 0, 0)
        expectNear(Astronomy.next(.newMoon, after: start), utc(2024, 10, 2, 18, 49), minutes: 15)
        expectNear(Astronomy.next(.firstQuarter, after: utc(2024, 10, 3, 0, 0)), utc(2024, 10, 10, 18, 55), minutes: 15)
        expectNear(Astronomy.next(.fullMoon, after: utc(2024, 10, 3, 0, 0)), utc(2024, 10, 17, 11, 26), minutes: 15)
        expectNear(Astronomy.next(.lastQuarter, after: utc(2024, 10, 18, 0, 0)), utc(2024, 10, 24, 8, 3), minutes: 15)
    }

    @Test("The Moon at full moon is full")
    func illumination() {
        let moon = Astronomy.moon(at: utc(2024, 10, 17, 11, 26))
        #expect(moon.phase == .fullMoon)
        #expect(moon.illumination > 0.99)
        let crescent = Astronomy.moon(at: utc(2024, 10, 5, 12, 0))
        #expect(crescent.phase == .waxingCrescent)
    }

    @Test("Equinoxes and solstices of 2025")
    func seasons() {
        expectNear(Astronomy.next(.marchEquinox, after: utc(2025, 1, 1, 0, 0)), utc(2025, 3, 20, 9, 1), minutes: 20)
        expectNear(Astronomy.next(.juneSolstice, after: utc(2025, 1, 1, 0, 0)), utc(2025, 6, 21, 2, 42), minutes: 20)
        expectNear(Astronomy.next(.decemberSolstice, after: utc(2025, 1, 1, 0, 0)), utc(2025, 12, 21, 15, 3), minutes: 20)
        #expect(Astronomy.nextSeason(after: utc(2025, 10, 12, 0, 0)).season == .decemberSolstice)
    }

    @Test("Moonrise and moonset happen on a full-moon day in Berlin")
    func moonTimes() {
        let calendar = Calendar.fixture(timeZone: "Europe/Berlin")
        let start = calendar.date(2024, 10, 17, 0, 0)
        let end = calendar.date(2024, 10, 18, 0, 0)
        let times = Astronomy.moonTimes(dayStart: start, dayEnd: end, latitude: 52.52, longitude: 13.405)
        // Full moon rises around sunset and sets around sunrise.
        let rise = calendar.dateComponents([.hour], from: times.rise!).hour!
        let set = calendar.dateComponents([.hour], from: times.set!).hour!
        #expect((17...19).contains(rise))
        #expect((7...10).contains(set))
    }

    @Test("The next clock change in Berlin")
    func clockChange() {
        let change = Astronomy.nextClockChange(after: Calendar.fixture(timeZone: "Europe/Berlin").date(2025, 10, 12, 0, 0), in: TimeZone(identifier: "Europe/Berlin")!)
        #expect(change?.shift == -3600)
        #expect(change?.date == utc(2025, 10, 26, 1, 0))
    }
}

@Suite("Time tools")
struct TimeToolTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("Reading durations", arguments: [
        ("1:45", 6300.0), ("1:45:30", 6330.0), ("1.75", 6300.0), ("1,5", 5400.0), ("1h 45m", 6300.0), ("90m", 5400.0), ("-0:30", -1800.0),
    ])
    func parse(text: String, seconds: Double) {
        #expect(HoursMath.seconds(from: text) == seconds)
    }

    @Test("Unreadable durations")
    func unreadable() {
        #expect(HoursMath.seconds(from: "abc") == nil)
        #expect(HoursMath.seconds(from: "1:75") == nil)
        #expect(HoursMath.seconds(from: "") == nil)
    }

    @Test("Formatting and overnight spans")
    func format() {
        #expect(HoursMath.clockText(6300) == "1:45")
        #expect(HoursMath.clockText(-1800) == "−0:30")
        #expect(HoursMath.span(from: DateComponents(hour: 22, minute: 0), to: DateComponents(hour: 6, minute: 0)) == 8 * 3600)
        #expect(HoursMath.span(from: DateComponents(hour: 9, minute: 15), to: DateComponents(hour: 17, minute: 45)) == 8.5 * 3600)
    }

    @Test("Age facts")
    func age() {
        let birth = calendar.date(1990, 3, 1, 0, 0)
        let facts = AgeFacts(birth: birth, now: calendar.date(2025, 10, 12, 12, 0), calendar: calendar)
        #expect(facts.age.years == 35)
        #expect(facts.age.months == 7)
        #expect(facts.age.days == 11)
        #expect(facts.nextBirthday == calendar.date(2026, 3, 1, 0, 0))
        #expect(facts.nextHalfBirthday == calendar.date(2026, 9, 1, 0, 0))
        #expect(facts.weekdayOfBirth == 5) // a Thursday
        #expect(abs(facts.planetAges.first { $0.planet == .mars }!.years - 18.94) < 0.05)
    }

    @Test("Progress through the day and year")
    func periods() {
        let noon = calendar.date(2025, 7, 2, 12, 0)
        #expect(abs(PeriodProgress.progress(of: .day, at: noon, calendar: calendar).elapsed - 0.5) < 0.0001)
        #expect(abs(PeriodProgress.progress(of: .year, at: noon, calendar: calendar).elapsed - 0.5) < 0.01)
    }

    @Test("Streaks")
    func streaks() {
        let streaks = Streaks(
            start: calendar.date(2025, 10, 1, 0, 0),
            previousStarts: [calendar.date(2025, 6, 1, 0, 0), calendar.date(2025, 1, 1, 0, 0)],
            now: calendar.date(2025, 10, 11, 0, 0),
            calendar: calendar
        )
        #expect(streaks.current == 10)
        #expect(streaks.longest == 151) // 1 January to 1 June
        #expect(streaks.resets == 2)
    }
}
