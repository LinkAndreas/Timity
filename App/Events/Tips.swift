import SwiftUI
import TipKit

/// Hints for what's easy to miss, each shown once it's useful and gone for good once
/// used or closed. TipKit shows at most one a day (see `AppComposition`).

/// Pinning, once there are a few events and none is pinned.
nonisolated struct PinEventTip: Tip {
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
