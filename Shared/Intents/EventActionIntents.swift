import AppIntents
import Foundation

/// Pins or unpins an event from a widget, in place.
struct TogglePinIntent: AppIntent {
    static let title: LocalizedStringResource = "intents.pinOrUnpinEvent"
    static let isDiscoverable = false

    @Parameter(title: "common.event")
    var eventID: String

    @Dependency private var repository: any EventRepository
    @Dependency private var widgets: any WidgetRefreshing

    init() {}

    init(eventID: UUID) {
        self.eventID = eventID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: eventID) else { return .result() }
        repository.update(id) { $0.isPinned.toggle() }
        widgets.reloadAll()
        return .result()
    }
}

/// Starts a "since" counter over from a widget, in place.
struct StartOverIntent: AppIntent {
    static let title: LocalizedStringResource = "common.startOver"
    static let isDiscoverable = false

    @Parameter(title: "common.event")
    var eventID: String

    @Dependency private var repository: any EventRepository
    @Dependency private var widgets: any WidgetRefreshing

    init() {}

    init(eventID: UUID) {
        self.eventID = eventID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: eventID) else { return .result() }
        repository.update(id) { $0.startOver() }
        widgets.reloadAll()
        return .result()
    }
}
