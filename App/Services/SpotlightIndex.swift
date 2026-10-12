import CoreSpotlight
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Events in Spotlight search, with their countdown, opening in Timity.
enum SpotlightIndex {
    static let activityType = CSSearchableItemActionType
    private static let domain = "de.link.timity.events"

    /// Replaces the index with the current events.
    @MainActor
    static func update(container: ModelContainer, now: Date = .now) async {
        let events = ((try? container.mainContext.fetch(FetchDescriptor<Event>())) ?? []).filter { !$0.isArchived }
        let items = events.map { event -> CSSearchableItem in
            let snapshot = event.snapshot
            let countdown = snapshot.countdown(at: now)
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = event.title
            attributes.contentDescription = "\(CountdownText.relativeDays(countdown)) · \(countdown.targetText)"
            attributes.keywords = [event.listName].filter { !$0.isEmpty }
            attributes.thumbnailData = event.imageData
            return CSSearchableItem(uniqueIdentifier: event.id.uuidString, domainIdentifier: domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteSearchableItems(withDomainIdentifiers: [domain])
            try await index.indexSearchableItems(items)
        } catch {
            logger.error("Couldn't update Spotlight: \(error)")
        }
    }

    static func eventID(in activity: NSUserActivity) -> UUID? {
        (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:))
    }
}
