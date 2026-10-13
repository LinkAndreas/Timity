import Foundation
import Observation

/// Where the app is, so widgets, notifications, menus and Siri can take the user somewhere.
@MainActor
@Observable
final class Navigator {
    enum Tab: Hashable {
        case events, calculators, sun, settings
    }

    var tab: Tab = .events
    var calculator: CalculatorTool?
    let events = EventsNavigation()

    func showEvent(_ id: UUID) {
        tab = .events
        events.selectedEventID = id
    }

    /// Opens the editor for a new event, filled in from `draft` if given.
    func addEvent(from draft: EventDraft? = nil) {
        tab = .events
        events.pendingTemplate = draft
        events.isAddingEvent = true
    }

    /// Handles `timity://event/<id>`, `timity://new` and `timity://life`.
    func open(_ url: URL) {
        if let id = DeepLink.eventID(in: url) {
            showEvent(id)
        } else if url == DeepLink.newEvent {
            addEvent()
        } else if url == DeepLink.lifeInWeeks {
            tab = .calculators
            calculator = .lifeInWeeks
        }
    }
}

/// What the Events tab shows: the chosen event and the sheets over it.
@MainActor
@Observable
final class EventsNavigation {
    var selectedEventID: UUID?
    var isAddingEvent = false
    var isPickingTemplate = false
    var isShowingYearInReview = false
    var isImporting = false
    /// Values for the next new event, from a received `.timity` file or a template.
    var pendingTemplate: EventDraft?
}
