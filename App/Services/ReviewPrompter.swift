import Foundation
import Observation

/// When to ask for an App Store rating: only someone who keeps coming back and has
/// had a few good moments — saving an event, opening one on its day — and at most
/// once per version. Apple's own prompt does the asking and decides whether it
/// appears at all; Timity never asks with a prompt of its own.
@MainActor
@Observable
final class ReviewPrompter {
    /// What's known about the user's time with Timity, kept between launches.
    struct Record: Codable, Equatable {
        var firstUse: Date?
        var lastActiveDay: Date?
        var activeDays = 0
        var happyMoments = 0
        /// The last day an event was opened on its day, so that counts once a day.
        var lastEventDay: Date?
        var promptedVersion: String?
    }

    enum Rules {
        static let daysSinceFirstUse = 7
        static let activeDays = 4
        static let happyMoments = 3
    }

    /// Whether the prompt should show now.
    private(set) var isDue = false

    @ObservationIgnored private var record: Record
    @ObservationIgnored private let store: any KeyValueStore
    @ObservationIgnored private let version: String
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let isSetUp: () -> Bool

    private static let key = "reviewPrompt"

    /// - Parameters:
    ///   - version: The app version; the prompt comes at most once in each.
    ///   - isSetUp: Whether the welcome is done; never during it.
    init(store: any KeyValueStore, version: String, calendar: Calendar = .autoupdatingCurrent, isSetUp: @escaping () -> Bool) {
        self.store = store
        self.version = version
        self.calendar = calendar
        self.isSetUp = isSetUp
        record = store.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Record.self, from: $0) } ?? Record()
    }

    /// The app came to the front; each day counts once.
    func recordActiveDay(now: Date = .now) {
        if record.firstUse == nil { record.firstUse = now }
        if record.lastActiveDay.map({ !calendar.isDate($0, inSameDayAs: now) }) ?? true {
            record.activeDays += 1
            record.lastActiveDay = now
        }
        save()
    }

    /// A new event was saved.
    func recordHappyMoment(now: Date = .now) {
        record.happyMoments += 1
        save()
        update(now: now)
    }

    /// An event was opened on its day; counts once a day, however many are opened.
    func recordEventDay(now: Date = .now) {
        guard record.lastEventDay.map({ !calendar.isDate($0, inSameDayAs: now) }) ?? true else { return }
        record.lastEventDay = now
        recordHappyMoment(now: now)
    }

    /// The prompt was asked for; the next chance comes with the next version, after
    /// as many good moments again.
    func didPrompt() {
        record.promptedVersion = version
        record.happyMoments = 0
        isDue = false
        save()
    }

    private func update(now: Date) {
        isDue = isSetUp() && Self.isDue(record, version: version, now: now, calendar: calendar)
    }

    private func save() {
        store.set(try? JSONEncoder().encode(record), forKey: Self.key)
    }

    nonisolated static func isDue(_ record: Record, version: String, now: Date, calendar: Calendar) -> Bool {
        guard record.promptedVersion != version, let firstUse = record.firstUse else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstUse), to: calendar.startOfDay(for: now)).day ?? 0
        return days >= Rules.daysSinceFirstUse
            && record.activeDays >= Rules.activeDays
            && record.happyMoments >= Rules.happyMoments
    }
}
