import ActivityKit
import SwiftUI
import WidgetKit

/// The countdown's last hours on the Lock Screen and in the Dynamic Island.
struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            LockScreenCountdown(attributes: context.attributes, state: context.state, isOver: context.isStale)
                // The card's own colour reaches the rounded edges the system draws.
                .activityBackgroundTint(context.attributes.color.color)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.event(context.attributes.eventID))
        } dynamicIsland: { context in
            let attributes = context.attributes
            let state = context.state
            let color = attributes.color.color
            return DynamicIsland {
                // Beside the camera, what and when; below it, across the whole width,
                // the name, the time left and how close the moment is.
                DynamicIslandExpandedRegion(.leading) {
                    EventBadge(symbolName: attributes.symbolName, color: attributes.color, size: 40)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(state.target, format: .dateTime.hour().minute())
                            .font(.headline.monospacedDigit())
                        Text(state.target, format: .dateTime.weekday(.wide))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            // A long name wraps onto a second line rather than being cut short.
                            Text(attributes.title)
                                .font(.headline)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            TimeLeft(target: state.target, isOver: context.isStale)
                                .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(color)
                        }
                        TimeProgress(state: state)
                            .tint(color)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: attributes.symbolName)
                    .foregroundStyle(color)
            } compactTrailing: {
                // A plain width cap here: the compact island sizes itself to its content,
                // and a width taken from hidden text keeps it measuring and never drawing.
                Group {
                    if context.isStale {
                        Text("common.now")
                    } else {
                        Text(timerInterval: min(Date.now, state.target)...state.target, countsDown: true)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: 56)
                .foregroundStyle(color)
            } minimal: {
                Image(systemName: attributes.symbolName)
                    .foregroundStyle(color)
            }
            .widgetURL(DeepLink.event(attributes.eventID))
            .keylineTint(color)
        }
    }
}

/// The event's own card, as in the widgets: white on its colour, the time left
/// large beside the name, and how close the moment is across the width.
private struct LockScreenCountdown: View {
    let attributes: CountdownActivityAttributes
    let state: CountdownActivityAttributes.ContentState
    /// Whether the moment has come.
    let isOver: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: attributes.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.22), in: .rect(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(state.target, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.subheadline)
                        .opacity(0.8)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                TimeLeft(target: state.target, isOver: isOver)
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
            }
            TimeProgress(state: state)
                .tint(.white)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(attributes.color.gradient)
        .accessibilityElement(children: .combine)
    }
}

/// The time left, exactly as wide as its longest reading, and "Now" once the
/// moment has come. A timer's text has no width of its own: it takes all the
/// room it's offered, and fixed to its ideal size it pushes everything beside it out.
private struct TimeLeft: View {
    let target: Date
    let isOver: Bool

    var body: some View {
        // Live Activities are offered for the last eight hours, so h:mm:ss is the longest it reads.
        Text(verbatim: "0:00:00")
            .hidden()
            .overlay(alignment: .trailing) {
                if isOver {
                    Text("common.now")
                        .minimumScaleFactor(0.5)
                } else {
                    Text(timerInterval: min(Date.now, target)...target, countsDown: true)
                        .multilineTextAlignment(.trailing)
                }
            }
            .lineLimit(1)
    }
}

/// How close the moment is, filling up over the activity's last hours.
private struct TimeProgress: View {
    let state: CountdownActivityAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: min(state.start, state.target)...state.target, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
    }
}
