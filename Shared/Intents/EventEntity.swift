import AppIntents
import Foundation

/// An event as Shortcuts, Siri and widget configuration see it.
struct EventEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"
    static let defaultQuery = EventQuery()

    let id: UUID
    let title: String
    let symbolName: String
    let subtitle: String

    init(_ snapshot: EventSnapshot, now: Date = .now) {
        id = snapshot.id
        title = snapshot.title
        symbolName = snapshot.symbolName
        subtitle = CountdownText.relativeDays(snapshot.countdown(at: now))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)",
            image: DisplayRepresentation.Image(systemName: symbolName)
        )
    }
}

struct EventQuery: EntityStringQuery {
    @Dependency private var reader: any EventReader

    func entities(for identifiers: [EventEntity.ID]) async throws -> [EventEntity] {
        let wanted = Set(identifiers)
        return reader.fetchEvents()
            .filter { wanted.contains($0.id) }
            .map { EventEntity($0) }
    }

    func entities(matching string: String) async throws -> [EventEntity] {
        reader.fetchEvents()
            .filter { $0.title.localizedStandardContains(string) }
            .sortedByCountdown()
            .map { EventEntity($0) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        reader.fetchEvents()
            .active
            .sortedByCountdown()
            .map { EventEntity($0) }
    }
}

/// Picks the event a countdown widget shows; without one it shows the next event.
struct SelectEventIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Event"
    static let description = IntentDescription("Shows the countdown to an event.")

    @Parameter(title: "Event")
    var event: EventEntity?

    init() {}

    init(event: EventEntity?) {
        self.event = event
    }
}
