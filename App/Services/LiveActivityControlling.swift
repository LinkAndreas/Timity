#if os(iOS)
import ActivityKit
#endif
import Foundation

/// Puts an event's last hours on the Lock Screen and in the Dynamic Island.
@MainActor
protocol LiveActivityControlling {
    /// Whether a Live Activity can be offered for the countdown: soon enough, and allowed.
    func canStart(for countdown: Countdown, now: Date) -> Bool
    func isRunning(for eventID: UUID) -> Bool
    func start(for event: EventSnapshot, target: Date)
    func end(for eventID: UUID) async
    /// Ends activities whose event has passed or is gone.
    func endFinished(existing eventIDs: Set<UUID>, now: Date) async
}

/// Where there are no Live Activities, as on the Mac: nothing is ever offered.
struct NoLiveActivities: LiveActivityControlling {
    func canStart(for countdown: Countdown, now: Date) -> Bool { false }
    func isRunning(for eventID: UUID) -> Bool { false }
    func start(for event: EventSnapshot, target: Date) {}
    func end(for eventID: UUID) async {}
    func endFinished(existing eventIDs: Set<UUID>, now: Date) async {}
}

#if os(iOS)
struct ActivityKitLiveActivities: LiveActivityControlling {
    /// Live Activities run for up to eight hours; offering one further out would end before the event.
    static let maximumLead: TimeInterval = 8 * 3600

    func canStart(for countdown: Countdown, now: Date) -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
            && countdown.direction == .future
            && countdown.target.timeIntervalSince(now) <= Self.maximumLead
    }

    func isRunning(for eventID: UUID) -> Bool {
        Activity<CountdownActivityAttributes>.activities.contains { $0.attributes.eventID == eventID }
    }

    func start(for event: EventSnapshot, target: Date) {
        let attributes = CountdownActivityAttributes(
            eventID: event.id,
            title: event.title,
            symbolName: event.symbolName,
            colorRawValue: event.color.rawValue
        )
        // The bar fills over the last hours, whenever it was started, so it shows how close
        // the moment is rather than starting empty.
        let state = CountdownActivityAttributes.ContentState(start: target.addingTimeInterval(-Self.maximumLead), target: target)
        do {
            _ = try Activity.request(
                attributes: attributes,
                // Stale from the moment itself, when the time left gives way to "Now".
                content: ActivityContent(state: state, staleDate: target),
                pushType: nil
            )
        } catch {
            logger.error("Couldn't start the Live Activity: \(error)")
        }
    }

    func end(for eventID: UUID) async {
        for activity in Activity<CountdownActivityAttributes>.activities where activity.attributes.eventID == eventID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func endFinished(existing eventIDs: Set<UUID>, now: Date) async {
        for activity in Activity<CountdownActivityAttributes>.activities {
            let state = activity.content.state
            if !eventIDs.contains(activity.attributes.eventID) || state.target.addingTimeInterval(15 * 60) < now {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
