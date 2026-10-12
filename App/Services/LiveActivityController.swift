import ActivityKit
import Foundation

/// Starts and ends Live Activities for events in their last hours.
enum LiveActivityController {
    /// Live Activities run for up to eight hours; offering one further out would end before the event.
    static let maximumLead: TimeInterval = 8 * 3600

    static var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func canStart(for countdown: Countdown, now: Date = .now) -> Bool {
        areEnabled && countdown.direction == .future && countdown.target.timeIntervalSince(now) <= maximumLead
    }

    static func isRunning(for eventID: UUID) -> Bool {
        Activity<CountdownActivityAttributes>.activities.contains { $0.attributes.eventID == eventID }
    }

    static func start(for event: Event, target: Date) {
        let attributes = CountdownActivityAttributes(
            eventID: event.id,
            title: event.title,
            symbolName: event.symbolName,
            colorRawValue: event.colorRawValue
        )
        let state = CountdownActivityAttributes.ContentState(start: .now, target: target)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: target.addingTimeInterval(15 * 60)),
                pushType: nil
            )
        } catch {
            logger.error("Couldn't start the Live Activity: \(error)")
        }
    }

    static func end(for eventID: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities where activity.attributes.eventID == eventID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends activities whose event has passed or been deleted, e.g. on launch.
    static func endFinished(existing eventIDs: Set<UUID>, now: Date = .now) async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            let state = activity.content.state
            if !eventIDs.contains(activity.attributes.eventID) || state.target.addingTimeInterval(15 * 60) < now {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
