#if os(iOS)
import ActivityKit
import Foundation

/// A countdown on the Lock Screen and in the Dynamic Island, for the last hours before an event.
nonisolated struct CountdownActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// When the countdown was started, for the progress bar.
        var start: Date
        var target: Date
    }

    let eventID: UUID
    let title: String
    let symbolName: String
    let colorRawValue: String

    var color: EventColor {
        EventColor(rawValue: colorRawValue) ?? .orange
    }
}
#endif
