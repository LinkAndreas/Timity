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
