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
    /// Brings the app's window to the front, opening it again on the Mac if it was
    /// closed; set by the window once it's shown.
    @ObservationIgnored var showWindow: () -> Void = {}

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

    /// Handles `timity://event/<id>`, `timity://new`, `timity://life` and `timity://astronomy`.
    func open(_ url: URL) {
        if let id = DeepLink.eventID(in: url) {
            showEvent(id)
        } else if url == DeepLink.newEvent {
            addEvent()
        } else if url == DeepLink.lifeInWeeks {
            tab = .calculators
            calculator = .lifeInWeeks
        } else if url == DeepLink.astronomy {
            tab = .sun
        }
    }
}

/// What the Events tab shows: the chosen event and the sheets over it.
@MainActor
@Observable
final class EventsNavigation {
    var selectedEventID: UUID?
    /// What the events are searched for, shared by the list and, on the Mac, the
    /// toolbar beside the event shown.
    var searchText = ""
    /// Counts up each time Find (⌘F) asks for the search field.
    var searchRequests = 0
    /// On the Mac, the events picked together with ⌘- or ⇧-click, when more than one.
    var pickedIDs: Set<UUID> = []
    var isAddingEvent = false
    var isShowingYearInReview = false
    var isImporting = false
    /// Values for the next new event, from a received `.timity` file or a template.
    var pendingTemplate: EventDraft?
    /// The events just deleted, which Undo brings back while its banner shows.
    var recentlyDeleted: [EventSnapshot] = []
}
