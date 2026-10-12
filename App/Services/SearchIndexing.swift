import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Makes events findable in system search, opening in Timity.
protocol SearchIndexing: Sendable {
    /// The user activity type the app receives when an event is chosen in search.
    var activityType: String { get }
    /// Replaces the index with these events.
    func update(_ events: [EventSnapshot]) async
    /// The event a search result opened, if any.
    func eventID(in activity: NSUserActivity) -> UUID?
}

/// Events in Spotlight, with their countdown.
struct SpotlightSearchIndex: SearchIndexing {
    private static let domain = "de.link.timity.events"

    var activityType: String { CSSearchableItemActionType }

    func update(_ events: [EventSnapshot]) async {
        let now = Date.now
        let items = events.active.map { event -> CSSearchableItem in
            let countdown = event.countdown(at: now)
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = event.title
            attributes.contentDescription = "\(CountdownText.relativeDays(countdown)) · \(countdown.targetText)"
            attributes.keywords = [event.listName].filter { !$0.isEmpty }
            attributes.thumbnailData = event.imageData
            return CSSearchableItem(uniqueIdentifier: event.id.uuidString, domainIdentifier: Self.domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domain])
            try await index.indexSearchableItems(items)
        } catch {
            logger.error("Couldn't update Spotlight: \(error)")
        }
    }

    func eventID(in activity: NSUserActivity) -> UUID? {
        (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:))
    }
}
