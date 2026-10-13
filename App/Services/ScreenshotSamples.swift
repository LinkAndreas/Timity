#if DEBUG
import Foundation

/// Sample events for App Store and README screenshots, added when a debug build
/// is launched with `-ScreenshotSamples`. They replace the events on the device.
enum ScreenshotSamples {
    @MainActor
    static func addIfAsked(to repository: any EventRepository) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotSamples") else { return }
        repository.events.forEach { repository.delete($0.id) }
        repository.save(events(now: .now))
    }

    private static func events(now: Date) -> [EventSnapshot] {
        let calendar = Calendar.autoupdatingCurrent
        func day(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now)) ?? now }
        func event(_ title: String, in days: Int, symbol: String, color: EventColor, recurrence: Recurrence = .never,
                   list: String = "", pinned: Bool = false, progress: Bool = false, checklist: [String] = []) -> EventSnapshot {
            var event = EventSnapshot(title: title, isAllDay: true, recurrence: recurrence, color: color, symbolName: symbol, isPinned: pinned)
            event.setStartDate(day(days))
            event.listName = list
            event.showsProgress = progress
            event.progressStart = progress ? day(-60) : nil
            event.checklist = checklist.map { ChecklistItem(title: $0) }
            return event
        }
        return [
            event("Trip to Lisbon", in: 12, symbol: "airplane", color: .lagoon, list: "Travel", pinned: true, progress: true,
                  checklist: ["Book hotel", "Passport", "Pack sunscreen"]),
            event("Mum's Birthday", in: 23, symbol: "birthday.cake.fill", color: .blossom, recurrence: .yearly, list: "Family", pinned: true),
            event("Final Exam", in: 5, symbol: "graduationcap.fill", color: .indigo, list: "Work"),
            event("Concert", in: 41, symbol: "music.note", color: .purple),
            event("Wedding Anniversary", in: 96, symbol: "heart.fill", color: .red, recurrence: .yearly, list: "Family"),
            event("Christmas", in: daysUntilChristmas(now: now, calendar: calendar), symbol: "gift.fill", color: .ember, recurrence: .yearly),
            event("Smoke-Free", in: -214, symbol: "leaf.fill", color: .green),
            event("Moved to Berlin", in: -680, symbol: "house.fill", color: .orange),
        ]
    }

    private static func daysUntilChristmas(now: Date, calendar: Calendar) -> Int {
        let year = calendar.component(.year, from: now)
        let christmas = calendar.date(from: DateComponents(year: year, month: 12, day: 25)) ?? now
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: christmas).day ?? 0
    }
}
#endif
