import Foundation
import Testing
@testable import Timity

@Suite("Countdowns")
struct CountdownTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    private func snapshot(_ date: Date, allDay: Bool = false, recurrence: Recurrence = .never) -> EventSnapshot {
        EventSnapshot(
            id: UUID(),
            title: "Event",
            date: allDay ? FloatingDay.storedDate(forDayOf: date, calendar: calendar) : date,
            isAllDay: allDay,
            recurrence: recurrence,
            color: .orange,
            symbolName: "star.fill",
            isPinned: false,
            imageData: nil
        )
    }

    @Test("An all-day event is today for its whole day")
    func allDayToday() {
        let now = calendar.date(2025, 10, 12, 21, 0)
        let countdown = snapshot(calendar.date(2025, 10, 12, 0, 0), allDay: true).countdown(at: now, calendar: calendar)
        #expect(countdown.isToday)
        #expect(countdown.direction == .present)
    }

    @Test("Tomorrow is one day away, even late in the evening")
    func tomorrow() {
        let now = calendar.date(2025, 10, 12, 23, 50)
        let countdown = snapshot(calendar.date(2025, 10, 13, 0, 10)).countdown(at: now, calendar: calendar)
        #expect(countdown.days == 1)
        #expect(countdown.direction == .future)
    }

    @Test("Days across the spring change aren't one short")
    func daysAcrossDaylightSaving() {
        // Timity 3 divided seconds by 86,400, which made this 29 days.
        let now = calendar.date(2025, 3, 15, 0, 0)
        let countdown = snapshot(calendar.date(2025, 4, 14, 0, 0), allDay: true).countdown(at: now, calendar: calendar)
        #expect(countdown.days == 30)
    }

    @Test("Upcoming events come first, soonest first; then past events, latest first")
    func sorting() {
        let now = calendar.date(2025, 10, 12, 12, 0)
        let soon = snapshot(calendar.date(2025, 10, 20, 0, 0))
        let later = snapshot(calendar.date(2026, 1, 1, 0, 0))
        let recent = snapshot(calendar.date(2025, 10, 1, 0, 0))
        let longAgo = snapshot(calendar.date(2020, 1, 1, 0, 0))
        let birthday = snapshot(calendar.date(1990, 10, 15, 0, 0), allDay: true, recurrence: .yearly)

        let sorted = [longAgo, later, recent, birthday, soon].sortedByCountdown(at: now)
        #expect(sorted.map(\.id) == [birthday, soon, later, recent, longAgo].map(\.id))
    }
}

@Suite("Events in other time zones")
struct TimeZoneEventTests {
    @Test("A weekly 9:00 meeting in New York stays at 9:00 there while Europe hasn't changed its clocks yet")
    func weeklyAcrossDifferentDaylightSaving() {
        let berlin = Calendar.fixture(timeZone: "Europe/Berlin")
        let newYork = Calendar.fixture(timeZone: "America/New_York")
        // Wednesday 5 March 2025, 9:00 in New York; the US moves its clocks on 9 March, Europe on 30 March.
        let first = newYork.date(2025, 3, 5, 9, 0)
        let now = berlin.date(2025, 3, 13, 12, 0)
        let countdown = Countdown(
            startDate: first,
            isAllDay: false,
            rule: RecurrenceRule(frequency: .weekly),
            eventTimeZone: TimeZone(identifier: "America/New_York"),
            now: now,
            calendar: berlin
        )
        #expect(countdown.target == newYork.date(2025, 3, 19, 9, 0))
        #expect(newYork.component(.hour, from: countdown.target) == 9)
    }
}

@Suite("Event files")
struct EventFileTests {
    @Test("An event survives a round trip through a file")
    func roundTrip() throws {
        let snapshot = EventSnapshot(
            id: UUID(), title: "Wedding / Hochzeit", date: Date(timeIntervalSince1970: 1_800_000_000), isAllDay: true,
            recurrence: .yearly, color: .blossom, symbolName: "heart.fill", isPinned: true, imageData: Data([1, 2, 3]),
            timeZoneIdentifier: nil, listName: "Family", isArchived: false, isYearUnknown: false
        )
        let file = EventFile(snapshot, notes: "Bring flowers")
        let decoded = try EventFile.decode(file.encoded())
        #expect(decoded == file)
        #expect(file.fileName == "Wedding - Hochzeit.timity")
    }
}

@Suite("Progress")
struct ProgressTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("Halfway between when the event was added and when it happens")
    func oneOff() {
        let countdown = Countdown(
            startDate: calendar.date(2025, 12, 1, 0, 0),
            isAllDay: true,
            rule: .never,
            progressStart: calendar.date(2025, 10, 1, 0, 0),
            now: calendar.date(2025, 10, 31, 12, 0),
            calendar: calendar
        )
        #expect(abs(countdown.progress! - 0.5) < 0.01)
    }

    @Test("A birthday's progress runs from the last birthday")
    func repeating() {
        let countdown = Countdown(
            startDate: calendar.date(1990, 3, 1, 0, 0),
            isAllDay: true,
            rule: RecurrenceRule(frequency: .yearly),
            progressStart: calendar.date(2025, 10, 1, 0, 0),
            now: calendar.date(2025, 9, 1, 0, 0),
            calendar: calendar
        )
        // 1 March to 1 September is 184 of 365 days.
        #expect(abs(countdown.progress! - 184.0 / 365) < 0.005)
    }

    @Test("No progress unless asked for")
    func off() {
        let countdown = Countdown(startDate: calendar.date(2026, 1, 1, 0, 0), isAllDay: true, recurrence: .never, now: .now, calendar: calendar)
        #expect(countdown.progress == nil)
    }
}

@Suite("Year in review")
struct StatisticsTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    private func event(_ title: String, _ date: Date, _ rule: RecurrenceRule = .never) -> EventSnapshot {
        EventSnapshot(
            id: UUID(), title: title, date: date, isAllDay: false, recurrence: rule.frequency, color: .orange,
            symbolName: "star.fill", isPinned: false, imageData: nil,
            recurrenceInterval: rule.interval, recurrencePattern: rule.pattern
        )
    }

    @Test("Counts one-off and repeating occurrences in a year")
    func counts() {
        let events = [
            event("Trip", calendar.date(2025, 7, 10, 9, 0)),
            event("Old trip", calendar.date(2024, 7, 10, 9, 0)),
            event("Birthday", calendar.date(1990, 3, 1, 0, 0), RecurrenceRule(frequency: .yearly)),
            event("Payday", calendar.date(2025, 1, 31, 0, 0), RecurrenceRule(frequency: .monthly, pattern: .lastWorkingDay)),
        ]
        let stats = EventStatistics(events: events, year: 2025, now: calendar.date(2025, 7, 1, 0, 0), calendar: calendar)
        #expect(stats.totalEvents == 4)
        #expect(stats.occurrencesInYear == 1 + 1 + 12)
        // Birthday in March and six paydays (January to June) have passed by 1 July.
        #expect(stats.reachedInYear == 7)
        #expect(stats.occurrencesPerMonth[6] == 2) // the trip and July's payday
        #expect(stats.busiestMonth?.month == 3 || stats.busiestMonth?.month == 7)
        #expect(stats.oldestEvent?.title == "Birthday")
    }
}
