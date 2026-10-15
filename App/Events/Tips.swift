import SwiftUI
import TipKit

/// Hints for what's easy to miss, each shown once it's useful and gone for good once
/// used or closed. TipKit shows at most one a day (see `AppComposition`).

/// Pinning, once there are a few events and none is pinned.
struct PinEventTip: Tip {
    @Parameter static var eventCount: Int = 0
    @Parameter static var hasPinned: Bool = false

    var title: Text { Text("tips.pinWhatMatters") }
    var message: Text? { Text("tips.swipeRightOnAnEvent") }
    var image: Image? { Image(systemName: "pin.fill") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 3 }
        #Rule(Self.$hasPinned) { $0 == false }
    }
}

/// Searching, once the list is long enough to need it.
struct SearchEventsTip: Tip {
    @Parameter static var eventCount: Int = 0

    var title: Text { Text("tips.findAnyEvent") }
    var message: Text? { Text("tips.pullDownTheListTo") }
    var image: Image? { Image(systemName: "magnifyingglass") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 8 }
    }
}

/// The event's menu, after a few events have been opened.
struct EventMenuTip: Tip {
    static let eventOpened = Event(id: "eventOpened")

    var title: Text { Text("tips.moreForEveryEvent") }
    var message: Text? { Text("tips.theMenuSharesTheCountdown") }
    var image: Image? { Image(systemName: "ellipsis.circle") }

    var rules: [Rule] {
        #Rule(Self.eventOpened) { $0.donations.count >= 3 }
    }
}
