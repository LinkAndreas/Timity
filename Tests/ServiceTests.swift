import Foundation
import Observation
import Testing
@testable import Timity

@MainActor
@Observable
private final class FakeEventRepository: EventRepository {
    var events: [EventSnapshot] = []

    func save(_ saved: [EventSnapshot]) {
        for event in saved {
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = event
            } else {
                events.append(event)
            }
        }
    }

    func delete(_ id: UUID) {
        events.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeLocator: PlaceLocating {
    var authorization = LocationAuthorization.authorized
    var result: Result<Place, LocationError>

    init(_ result: Result<Place, LocationError>) {
        self.result = result
    }

    func locate() async throws -> Place {
        try result.get()
    }
}

@Suite("Reminders")
struct ReminderPlannerTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    private func event(_ date: Date, allDay: Bool = true, minutes: Int?, archived: Bool = false) -> EventSnapshot {
        var event = EventSnapshot(title: "Trip", isAllDay: allDay, isArchived: archived, reminderMinutes: minutes)
        event.setStartDate(date, calendar: calendar)
        return event
    }

    @Test("An all-day event's reminder comes at 9:00, the given time before")
    func allDay() {
        let now = calendar.date(2025, 10, 1, 12, 0)
        let reminders = ReminderPlanner.reminders(
            for: [event(calendar.date(2025, 10, 10, 0, 0), minutes: 1440)],
            includingMilestones: false, now: now, calendar: calendar
        )
        #expect(reminders.map(\.fireDate) == [calendar.date(2025, 10, 9, 9, 0)])
    }

    @Test("Archived events, events without a reminder and past reminders are left out")
    func leftOut() {
        let now = calendar.date(2025, 10, 1, 12, 0)
        let reminders = ReminderPlanner.reminders(
            for: [
                event(calendar.date(2025, 10, 10, 0, 0), minutes: 0, archived: true),
                event(calendar.date(2025, 10, 10, 0, 0), minutes: nil),
                event(calendar.date(2025, 9, 1, 0, 0), minutes: 0),
            ],
            includingMilestones: false, now: now, calendar: calendar
        )
        #expect(reminders.isEmpty)
    }

    @Test("Milestones only when asked for")
    func milestones() {
        // 10,000 days after 1 January 1998 is 19 May 2025.
        let birth = event(calendar.date(1998, 1, 1, 0, 0), minutes: nil)
        let now = calendar.date(2025, 5, 1, 12, 0)
        #expect(ReminderPlanner.reminders(for: [birth], includingMilestones: false, now: now, calendar: calendar).isEmpty)
        #expect(!ReminderPlanner.reminders(for: [birth], includingMilestones: true, now: now, calendar: calendar).isEmpty)
    }
}

@Suite("Event changes")
@MainActor
struct EventChangeCoordinatorTests {
    @Test("Changes in quick succession run the handlers once")
    func debounced() async throws {
        var calls = 0
        let coordinator = EventChangeCoordinator(repository: FakeEventRepository(), handlers: [{ _ in calls += 1 }])
        coordinator.refresh()
        coordinator.refresh()
        coordinator.refresh()
        try await Task.sleep(for: .milliseconds(800))
        #expect(calls == 1)
    }

    @Test("A change in the repository runs the handlers with the latest events")
    func followsRepository() async throws {
        let repository = FakeEventRepository()
        var received: [EventSnapshot]?
        let coordinator = EventChangeCoordinator(repository: repository, handlers: [{ received = $0 }])
        coordinator.start()
        try await Task.sleep(for: .milliseconds(800))

        let event = EventSnapshot(title: "Concert")
        repository.save(event)
        try await Task.sleep(for: .milliseconds(800))
        #expect(received?.map(\.id) == [event.id])
    }
}

@Suite("Sun place")
@MainActor
struct SunPlaceModelTests {
    let berlin = Place(latitude: 52.52, longitude: 13.4, timeZoneIdentifier: "Europe/Berlin", name: "Berlin")

    @Test("A found place is shown and handed on")
    func found() async {
        var handedOn: Place?
        let model = SunPlaceModel(place: nil, locator: FakeLocator(.success(berlin))) { handedOn = $0 }
        await model.locate()
        #expect(model.place == berlin)
        #expect(model.status == .idle)
        #expect(handedOn == berlin)
    }

    @Test("A chosen place is shown and saved, and the location isn't followed until asked")
    func chosen() async {
        let lisbon = Place(latitude: 38.72, longitude: -9.14, timeZoneIdentifier: "Europe/Lisbon", name: "Lisbon")
        var saved: SunPlaceModel.Choices?
        let model = SunPlaceModel(place: berlin, locator: FakeLocator(.success(berlin)), onChoices: { saved = $0 }) { _ in }
        model.choose(lisbon)
        #expect(model.place == lisbon)
        #expect(saved?.saved == [lisbon])
        #expect(saved?.followsLocation == false)

        await model.locate()
        #expect(model.place == lisbon)

        await model.useCurrentLocation()
        #expect(model.place == berlin)
        #expect(model.followsLocation)
        #expect(model.savedPlaces == [lisbon])
    }

    @Test("Without permission the last place stays")
    func denied() async {
        var handedOn: Place?
        let model = SunPlaceModel(place: berlin, locator: FakeLocator(.failure(.denied))) { handedOn = $0 }
        await model.locate()
        #expect(model.status == .denied)
        #expect(model.place == berlin)
        #expect(handedOn == nil)
    }
}

@Suite("Settings")
@MainActor
struct SettingsTests {
    @Test("Events sync only once the welcome, which asks about it, is done")
    func syncAfterOnboarding() {
        let settings = AppSettings(defaults: InMemoryKeyValueStore(), shared: SharedSettings(store: InMemoryKeyValueStore()))
        #expect(settings.syncsWithICloud)
        #expect(!settings.syncsAfterOnboarding)
        settings.hasCompletedOnboarding = true
        #expect(settings.syncsAfterOnboarding)
        settings.syncsWithICloud = false
        #expect(!settings.syncsAfterOnboarding)
    }

    @Test("Preferences are kept, and the birthday is shared with the widgets")
    func persisted() {
        let defaults = InMemoryKeyValueStore()
        let shared = SharedSettings(store: InMemoryKeyValueStore())
        let birthday = Date(timeIntervalSince1970: 600_000_000)

        let settings = AppSettings(defaults: defaults, shared: shared)
        settings.eventList.sort = .title
        settings.eventList.selectedList = "Family"
        settings.birthday = birthday

        let reopened = AppSettings(defaults: defaults, shared: shared)
        #expect(reopened.eventList.sort == .title)
        #expect(reopened.eventList.selectedList == "Family")
        #expect(shared.birthday == birthday)
    }
}

@Suite("Stored events")
@MainActor
struct SwiftDataEventRepositoryTests {
    @Test("Events survive a round trip through the store, and can be changed and deleted")
    func roundTrip() {
        let repository = SwiftDataEventRepository(database: EventDatabase(syncsWithICloud: false, inMemory: true))
        var event = EventSnapshot(
            title: "Marathon",
            recurrence: .yearly,
            color: .ember,
            notes: "Bring gels",
            reminderMinutes: 60,
            resetHistory: [Date(timeIntervalSince1970: 1_700_000_000)],
            checklist: [ChecklistItem(title: "Register")]
        )
        repository.save(event)
        #expect(repository.events == [event])

        repository.update(event.id) { $0.title = "Half Marathon" }
        #expect(repository.events.map(\.title) == ["Half Marathon"])

        event.isArchived = true
        repository.save(event)
        #expect(repository.events.first?.isArchived == true)

        repository.delete(event.id)
        #expect(repository.events.isEmpty)
    }
}

@Suite("iCloud sync")
struct CloudSyncStateTests {
    @Test("Syncing while a step runs, synced once it succeeds")
    func syncing() {
        var state = CloudSyncState(isEnabled: true)
        let id = UUID()
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        state.record(.init(id: id))
        #expect(state.isSyncing)
        state.record(.init(id: id, endDate: end, succeeded: true))
        #expect(!state.isSyncing)
        #expect(state.lastSynced == end)
        #expect(state.problem == nil)
    }

    @Test("A failure shows until a step succeeds")
    func failure() {
        var state = CloudSyncState(isEnabled: true)
        state.record(.init(id: UUID(), endDate: .now, problem: .storageFull, details: "CKErrorDomain 25: Quota Exceeded"))
        #expect(state.problem == .storageFull)
        #expect(state.problemDetails == "CKErrorDomain 25: Quota Exceeded")
        state.record(.init(id: UUID(), endDate: .now, succeeded: true))
        #expect(state.problem == nil)
    }

    @Test("A store that couldn't open with iCloud is a problem, whatever else is fine")
    func couldNotStart() {
        var state = CloudSyncState(isEnabled: true)
        state.account = .available
        state.storeSyncs = false
        #expect(state.problem == .couldNotStart)
    }

    @Test("Failures sync recovers from by itself, such as conflicts, aren't problems")
    func recovered() {
        var state = CloudSyncState(isEnabled: true)
        state.record(.init(id: UUID(), endDate: .now))
        #expect(state.problem == nil)
    }

    @Test("The account comes first, and nothing shows while sync is off")
    func account() {
        var state = CloudSyncState(isEnabled: true)
        state.account = .noAccount
        state.record(.init(id: UUID(), endDate: .now, problem: .offline))
        #expect(state.problem == .noAccount)

        state.setEnabled(false)
        state.record(.init(id: UUID()))
        #expect(state.problem == nil)
        #expect(!state.isSyncing)
    }
}

@Suite("Sleep and pregnancy")
struct SleepAndPregnancyTests {
    let calendar = Calendar.fixture(timeZone: "Europe/Berlin")

    @Test("Bedtimes leave whole cycles and time to fall asleep before waking")
    func bedtimes() {
        let wake = calendar.date(2025, 10, 2, 7, 0)
        let bedtimes = SleepCycles.bedtimes(toWakeAt: wake)
        #expect(bedtimes.map(\.cycles) == [6, 5, 4])
        #expect(bedtimes.first?.time == calendar.date(2025, 10, 1, 21, 45))
        #expect(SleepCycles.wakeTimes(goingToBedAt: calendar.date(2025, 10, 1, 23, 0)).last?.time == calendar.date(2025, 10, 2, 5, 15))
    }

    @Test("Due 40 weeks after the last period, counted in weeks and days")
    func pregnancy() {
        let pregnancy = Pregnancy(lastPeriod: calendar.date(2025, 1, 1, 0, 0), now: calendar.date(2025, 3, 30, 12, 0), calendar: calendar)
        #expect(pregnancy.dueDate == calendar.date(2025, 10, 8, 0, 0))
        #expect(pregnancy.weeks == 12)
        #expect(pregnancy.days == 4)
        #expect(pregnancy.trimester == 1)
        #expect(pregnancy.daysToGo == 280 - 88)
    }
}

@Suite("Syncing safely")
struct SyncSafetyTests {
    @Test("The same name gives the same ID, and another name another one")
    func stableIDs() {
        #expect(UUID(stableFrom: "import|birthday|Ada|0-12-10") == UUID(stableFrom: "import|birthday|Ada|0-12-10"))
        #expect(UUID(stableFrom: "import|birthday|Ada|0-12-10") != UUID(stableFrom: "import|birthday|Alan|0-6-23"))
    }

    @Test("Copies of an event show once, the most recently changed")
    func oneByID() {
        let id = UUID()
        let older = EventSnapshot(id: id, title: "Old", modifiedAt: Date(timeIntervalSince1970: 100))
        let newer = EventSnapshot(id: id, title: "New", modifiedAt: Date(timeIntervalSince1970: 200))
        let other = EventSnapshot(title: "Other")
        #expect([older, other, newer].oneByID.map(\.title) == ["New", "Other"])
    }

    /// Fails when a synced field is added or renamed. Before releasing it, run a
    /// debug build, tap Settings › iCloud › Prepare iCloud Schema, and deploy the
    /// schema to production in the CloudKit Console; then add the field here.
    @Test("Every synced field is deployed to production in CloudKit")
    func deployedSchema() {
        let deployed = [
            "calendarRawValue", "checklistData", "colorRawValue", "createdAt", "date", "id", "imageData",
            "isAllDay", "isArchived", "isPinned", "isYearUnknown", "listName", "modifiedAt", "notes",
            "progressStart", "recurrenceInterval", "recurrencePatternRawValue", "recurrenceRawValue",
            "reminderMinutes", "resetHistoryData", "showsProgress", "symbolName", "timeZoneIdentifier", "title",
        ]
        #expect(EventDatabase.syncedFieldNames == deployed)
    }
}

private struct FakeRemover: CloudEventsRemoving {
    var fails = false
    func removeEventsFromICloud() async throws {
        if fails { throw URLError(.notConnectedToInternet) }
    }
}

@Suite("Repairing sync")
@MainActor
struct CloudSyncRepairTests {
    private func makeRepair(remover: FakeRemover = FakeRemover()) -> (CloudSyncRepair, SwiftDataEventRepository, URL) {
        let database = EventDatabase(syncsWithICloud: false, inMemory: true)
        let repository = SwiftDataEventRepository(database: database)
        let url = FileManager.default.temporaryDirectory.appending(path: "PendingEvents-\(UUID()).json")
        return (CloudSyncRepair(database: database, repository: repository, remover: remover, pendingEventsURL: url), repository, url)
    }

    @Test("Uploading again and removing from iCloud keep every event on this device")
    func keepsEvents() async throws {
        let (repair, repository, url) = makeRepair()
        let events = [EventSnapshot(title: "Trip", checklist: [ChecklistItem(title: "Pack")]), EventSnapshot(title: "Exam")]
        repository.save(events)

        try await repair.uploadAgain()
        #expect(Set(repository.events.map(\.id)) == Set(events.map(\.id)))
        try await repair.removeFromICloud()
        #expect(repository.events.first { $0.title == "Trip" }?.checklist.map(\.title) == ["Pack"])
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("When iCloud can't be reached, nothing changes")
    func failedRemoval() async {
        let (repair, repository, url) = makeRepair(remover: FakeRemover(fails: true))
        repository.save(EventSnapshot(title: "Trip"))
        await #expect(throws: URLError.self) { try await repair.uploadAgain() }
        #expect(repository.events.map(\.title) == ["Trip"])
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Events kept from an unfinished rebuild are saved at the next launch")
    func restoresPending() throws {
        let (repair, repository, url) = makeRepair()
        try JSONEncoder().encode([EventSnapshot(title: "Saved")]).write(to: url)
        repair.restorePendingEvents()
        #expect(repository.events.map(\.title) == ["Saved"])
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}

@Suite("Bridge days and flights")
struct BridgeDaysAndFlightTests {
    let utc = Calendar.gregorianUTC

    @Test("A Thursday holiday plus Friday off makes a four-day weekend")
    func ascension() {
        // Ascension Day 2026 in Germany is Thursday 14 May.
        let breaks = BridgeDays.opportunities(in: 2026, region: .germany)
        let ascension = breaks.first { $0.holidays.contains("Christi Himmelfahrt") }
        #expect(ascension != nil)
        #expect(ascension?.daysOff ?? 0 >= 4)
        #expect((ascension?.leaveDays.count ?? 0) >= 1)
        #expect(breaks.allSatisfy { $0.daysOff >= 2 * $0.leaveDays.count + 1 })
    }

    @Test("Breaks don't overlap and come in date order")
    func distinct() {
        let breaks = BridgeDays.opportunities(in: 2026, region: .germany)
        for (a, b) in zip(breaks, breaks.dropFirst()) {
            #expect(a.end < b.start)
        }
    }

    @Test("A flight's arrival in local time, with the day it lands")
    func flight() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        let departure = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 10)))

        let west = FlightArrival.arrival(departure: departure, from: berlin, duration: 9 * 3600, to: newYork)
        calendar.timeZone = newYork
        #expect(calendar.dateComponents([.hour], from: west.arrival).hour == 13)
        #expect(west.dayChange == 0)
        #expect(west.timeDifference == -6 * 3600)

        let east = FlightArrival.arrival(departure: departure, from: berlin, duration: 13 * 3600, to: tokyo)
        #expect(east.dayChange == 1)
    }
}
