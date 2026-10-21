import Foundation
import Testing
@testable import Timity

@Suite("Export and import")
struct BackupTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func birthday() -> EventSnapshot {
        var event = EventSnapshot(title: "Mum's Birthday", isAllDay: true, recurrence: .yearly, color: .blossom, symbolName: "birthday.cake.fill")
        event.setStartDate(calendar.date(1960, 3, 14, 0, 0), calendar: calendar)
        event.listName = "Family"
        event.notes = "Flowers, \"tulips\" — not roses"
        event.isPinned = true
        event.reminderMinutes = 1440
        event.createdAt = now
        event.modifiedAt = now
        return event
    }

    private func flight() -> EventSnapshot {
        var event = EventSnapshot(title: "Flight to Tokyo", date: calendar.date(2026, 11, 5, 14, 30), isAllDay: false)
        event.timeZoneIdentifier = "Asia/Tokyo"
        event.createdAt = now
        event.modifiedAt = now
        return event
    }

    @Test("A JSON backup brings back every event as it was")
    func jsonRoundTrip() throws {
        var events = [birthday(), flight()]
        events[0].imageData = Data([1, 2, 3])
        events[0].resetHistory = [now]
        let data = try EventBackup.json(events, includingPhotos: true, now: now)
        let read = try EventBackup.events(from: data, calendar: calendar, now: now)
        #expect(read.events == events)
        #expect(read.skipped == 0)
    }

    @Test("A JSON backup can leave the photos out")
    func jsonWithoutPhotos() throws {
        var event = birthday()
        event.imageData = Data([1, 2, 3])
        let read = try EventBackup.events(from: EventBackup.json([event], includingPhotos: false, now: now), calendar: calendar, now: now)
        #expect(read.events.first?.imageData == nil)
    }

    @Test("A CSV keeps the day of all-day events and the local time where timed ones happen")
    func csvRoundTrip() throws {
        let events = [birthday(), flight()]
        let data = EventBackup.csv(events, calendar: calendar, separator: ",")
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("1960-03-14"))
        // 14:30 in Berlin is 22:30 in Tokyo, where the flight happens.
        #expect(text.contains("2026-11-05,22:30,no,Asia/Tokyo"))
        #expect(text.contains("\"Flowers, \"\"tulips\"\" — not roses\""))

        let read = try EventBackup.events(from: data, calendar: calendar, now: now)
        #expect(read.events.map(\.id) == events.map(\.id))
        #expect(read.events.map(\.date) == events.map(\.date))
        #expect(read.events.map(\.isAllDay) == [true, false])
        #expect(read.events.first?.notes == events.first?.notes)
        #expect(read.events.first?.listName == "Family")
        #expect(read.events.first?.recurrence == .yearly)
        #expect(read.events.first?.reminderMinutes == 1440)
        #expect(read.events.last?.timeZoneIdentifier == "Asia/Tokyo")
    }

    @Test("Quoted fields may hold separators, quotes and line breaks")
    func parsing() {
        let rows = EventBackup.parseCSV("a,\"b, c\",\"say \"\"hi\"\"\"\r\n\"two\nlines\",,end\n")
        #expect(rows == [["a", "b, c", "say \"hi\""], ["two\nlines", "", "end"]])
    }

    @Test("A spreadsheet from German Excel: semicolons, dotted dates, any column order")
    func germanSpreadsheet() throws {
        let csv = "Date;Title;Time\n05.11.2026;Konzert;20:00\n24.12.2026;Weihnachten;\n"
        let read = try EventBackup.events(from: Data(csv.utf8), calendar: calendar, now: now)
        #expect(read.events.map(\.title) == ["Konzert", "Weihnachten"])
        #expect(read.events.first?.date == calendar.date(2026, 11, 5, 20, 0))
        #expect(read.events.first?.isAllDay == false)
        #expect(read.events.last?.isAllDay == true)
        #expect(read.events.last?.startDate(in: calendar) == calendar.date(2026, 12, 24, 0, 0))
    }

    @Test("Rows without a title or a readable date are skipped and counted")
    func skipped() throws {
        let csv = "Title,Date\nTrip,2026-05-01\n,2026-05-02\nParty,someday\n\n"
        let read = try EventBackup.events(from: Data(csv.utf8), calendar: calendar, now: now)
        #expect(read.events.map(\.title) == ["Trip"])
        #expect(read.skipped == 2)
    }

    @Test("A file that's neither a backup nor a spreadsheet with Title and Date is refused")
    func unreadable() {
        #expect(throws: EventBackup.ImportError.unreadable) {
            try EventBackup.events(from: Data("Name,When\nTrip,tomorrow\n".utf8), calendar: calendar, now: now)
        }
    }

    @Test("Importing the same file twice adds nothing the second time")
    func importTwice() throws {
        let data = Data("Title,Date\nTrip,2026-05-01\n".utf8)
        let first = try EventBackup.events(from: data, calendar: calendar, now: now).events
        let merged = EventBackup.merge(first, into: [])
        #expect(merged.outcome == EventBackup.Outcome(added: 1))

        let later = try EventBackup.events(from: data, calendar: calendar, now: now.addingTimeInterval(3600)).events
        let again = EventBackup.merge(later, into: merged.toSave)
        #expect(again.toSave.isEmpty)
        #expect(again.outcome == EventBackup.Outcome(unchanged: 1))
    }

    @Test("A newer copy updates an event, an older one doesn't, and photos here stay")
    func mergeByDate() {
        var existing = birthday()
        existing.imageData = Data([9])
        var newer = existing
        newer.title = "Mum's 66th"
        newer.imageData = nil
        newer.modifiedAt = now.addingTimeInterval(60)
        var older = existing
        older.title = "Old name"
        older.modifiedAt = now.addingTimeInterval(-60)

        let updated = EventBackup.merge([newer], into: [existing])
        #expect(updated.outcome == EventBackup.Outcome(updated: 1))
        #expect(updated.toSave.first?.title == "Mum's 66th")
        #expect(updated.toSave.first?.imageData == Data([9]))

        #expect(EventBackup.merge([older], into: [existing]).outcome == EventBackup.Outcome(unchanged: 1))
    }
}
