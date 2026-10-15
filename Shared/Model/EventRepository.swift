import Foundation

/// Where the app's screens keep events. Reading `events` inside a view's body is
/// observed, so the view updates when events change here, in a widget or through iCloud.
@MainActor
protocol EventRepository: AnyObject, Sendable {
    /// Every event, archived ones included, in no particular order.
    var events: [EventSnapshot] { get }
    /// Adds the events, or replaces those with the same IDs.
    func save(_ events: [EventSnapshot])
    func delete(_ id: UUID)
}

extension EventRepository {
    func save(_ event: EventSnapshot) {
        save([event])
    }

    /// Changes one event in place, marking it modified.
    func update(_ id: UUID, _ change: (inout EventSnapshot) -> Void) {
        guard var event = events.first(where: { $0.id == id }) else { return }
        change(&event)
        event.modifiedAt = .now
        save(event)
    }
}

/// Reads events from any thread — for widgets and intents, which read once and
/// don't need to follow changes.
nonisolated protocol EventReader: Sendable {
    func fetchEvents() -> [EventSnapshot]
}
