import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Actions widgets run in place: pinning an event, and starting a counter over.
enum WidgetEventActions {
    /// Changes an event in the shared store; the app syncs it to iCloud next time it runs.
    static func update(_ id: UUID, _ change: (Event) -> Void) throws {
        let context = ModelContext(TimityStore.container)
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        guard let event = try context.fetch(descriptor).first else { return }
        change(event)
        event.modifiedAt = .now
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct TogglePinIntent: AppIntent {
    static let title: LocalizedStringResource = "Pin or Unpin Event"
    static let isDiscoverable = false

    @Parameter(title: "Event")
    var eventID: String

    init() {}

    init(eventID: UUID) {
        self.eventID = eventID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: eventID) else { return .result() }
        try WidgetEventActions.update(id) { $0.isPinned.toggle() }
        return .result()
    }
}

struct StartOverIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Over"
    static let isDiscoverable = false

    @Parameter(title: "Event")
    var eventID: String

    init() {}

    init(eventID: UUID) {
        self.eventID = eventID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: eventID) else { return .result() }
        try WidgetEventActions.update(id) { $0.startOver() }
        return .result()
    }
}
