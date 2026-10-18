import SwiftUI
import TipKit

/// Hints for what's easy to miss, each shown once it's useful and gone for good once
/// used or closed. TipKit shows at most one a day (see `AppComposition`).

/// Pinning, once there are a few events and none is pinned.
nonisolated struct PinEventTip: Tip {
    @Parameter static var eventCount: Int = 0
    @Parameter static var hasPinned: Bool = false

    var title: Text { Text("tips.pinWhatMatters") }
    #if os(macOS)
    var message: Text? { Text("tips.swipeRightOnAnEvent.mac") }
    #else
    var message: Text? { Text("tips.swipeRightOnAnEvent") }
    #endif
    var image: Image? { Image(systemName: "pin.fill") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 3 }
        #Rule(Self.$hasPinned) { $0 == false }
    }
}

/// Searching, once the list is long enough to need it.
nonisolated struct SearchEventsTip: Tip {
    @Parameter static var eventCount: Int = 0

    var title: Text { Text("tips.findAnyEvent") }
    var message: Text? { Text("tips.searchNamesAndNotes") }
    var image: Image? { Image(systemName: "magnifyingglass") }

    var rules: [Rule] {
        #Rule(Self.$eventCount) { $0 >= 8 }
    }
}

/// The event's menu, after a few events have been opened.
nonisolated struct EventMenuTip: Tip {
    static let eventOpened = Event(id: "eventOpened")

    var title: Text { Text("tips.moreForEveryEvent") }
    var message: Text? { Text("tips.theMenuSharesTheCountdown") }
    var image: Image? { Image(systemName: "ellipsis.circle") }

    var rules: [Rule] {
        #Rule(Self.eventOpened) { $0.donations.count >= 3 }
    }
}

/// Swiping between the Sun and the Moon, once the tab has been opened a second time.
nonisolated struct SwipeSkyTip: Tip {
    static let astronomyOpened = Event(id: "astronomyOpened")

    var title: Text { Text("tips.swipeBetweenSunAndMoon") }
    var message: Text? { Text("tips.swipeSidewaysAnywhereBelow") }
    var image: Image? { Image(systemName: "hand.draw") }

    var rules: [Rule] {
        #Rule(Self.astronomyOpened) { $0.donations.count >= 2 }
    }
}

/// That a date is a button: the first date of a calculator.
nonisolated struct DatePillTip: Tip {
    #if os(macOS)
    var title: Text { Text("tips.tapADateToChange.mac") }
    #else
    var title: Text { Text("tips.tapADateToChange") }
    #endif
    var message: Text? { Text("tips.aCalendarOpensRightBelow") }
    var image: Image? { Image(systemName: "calendar") }
}

/// The common amounts above Find a Date's fields.
nonisolated struct QuickAmountsTip: Tip {
    #if os(macOS)
    var title: Text { Text("tips.oneTapAmounts.mac") }
    #else
    var title: Text { Text("tips.oneTapAmounts") }
    #endif
    var message: Text? { Text("tips.pickACommonAmount") }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// For trying tips out, in test builds only: "Show Tips Again" brings every tip back
/// once, on the next start, and lets them all show that session rather than one a
/// day. Closing or using a tip still puts it away for good, as for everyone.
///
/// TipKit's own testing mode isn't used: it shows tips even after they're closed,
/// so they kept coming back.
enum TipTesting {
    static let showAgainKey = "tipTestingShowsAgain"
    /// The former switch for TipKit's testing mode; cleared on start.
    private static let formerShowsAllKey = "tipTestingShowsAll"
    private static let formerResetsKey = "tipTestingResets"

    /// The display frequency for `Tips.configure`: every tip at once after "Show
    /// Tips Again", else one a day.
    static func frequency(_ defaults: UserDefaults = .standard) -> Tips.ConfigurationOption.DisplayFrequency {
        defaults.removeObject(forKey: formerShowsAllKey)
        defaults.removeObject(forKey: formerResetsKey)
        guard defaults.bool(forKey: showAgainKey) else { return .daily }
        try? Tips.resetDatastore()
        defaults.set(false, forKey: showAgainKey)
        return .immediate
    }
}

/// Timity's look for tips in place: the symbol on a small tinted tile, as on the
/// welcome pages, the words beside it, and a quiet close button.
struct TimityTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if let image = configuration.image {
                image
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.tint, in: .rect(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                configuration.title?
                    .font(.headline)
                configuration.message?
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                configuration.tip.invalidate(reason: .tipClosed)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.fill.tertiary, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("common.close"))
        }
        .padding(16)
    }
}
