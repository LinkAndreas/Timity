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
        state.record(.init(id: UUID(), endDate: .now, problem: .storageFull))
        #expect(state.problem == .storageFull)
        state.record(.init(id: UUID(), endDate: .now, succeeded: true))
        #expect(state.problem == nil)
    }

    @Test("The account comes first, and nothing shows while sync is off")
    func account() {
        var state = CloudSyncState(isEnabled: true)
        state.account = .noAccount
        state.record(.init(id: UUID(), endDate: .now, problem: .offline))
        #expect(state.problem == .noAccount)
        #expect(state.glimpse != nil)

        state.setEnabled(false)
        state.record(.init(id: UUID()))
        #expect(state.problem == nil)
        #expect(!state.isSyncing)
        #expect(state.glimpse == nil)
    }
}
