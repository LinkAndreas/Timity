import SwiftUI
import TipKit

/// Hints for what's easy to miss, each shown once it's useful and gone for good once
/// used or closed. TipKit shows at most one a day (see `AppComposition`).

/// Pinning, once there are a few events and none is pinned.
struct PinEventTip: Tip {
    @Parameter static var eventCount = 0
    @Parameter static var hasPinned = false

    var title: Text { Text("Pin What Matters") }
    var message: Text? { Text("Swipe right on an event to pin it. Pinned events come first, as large cards.") }
    var image: Image? { Image(systemName: "pin.fill") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 3 }
        #Rule(Self.$hasPinned) { $0 == false }
    }
}

/// Searching, once the list is long enough to need it.
struct SearchEventsTip: Tip {
    @Parameter static var eventCount = 0

    var title: Text { Text("Find Any Event") }
    var message: Text? { Text("Pull down the list to search names and notes in every list, past and archived events too.") }
    var image: Image? { Image(systemName: "magnifyingglass") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 8 }
    }
}

/// The event's menu, after a few events have been opened.
struct EventMenuTip: Tip {
    static let eventOpened = Event(id: "eventOpened")

    var title: Text { Text("More for Every Event") }
    var message: Text? { Text("The ••• menu shares the countdown as an image, adds it to Calendar and starts a count over.") }
    var image: Image? { Image(systemName: "ellipsis.circle") }

    var rules: [Rule] {
        #Rule(Self.eventOpened) { $0.donations.count >= 3 }
    }
}
