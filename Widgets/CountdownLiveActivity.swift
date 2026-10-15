import ActivityKit
import SwiftUI
import WidgetKit

/// The countdown's last hours on the Lock Screen and in the Dynamic Island.
struct CountdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownActivityAttributes.self) { context in
            LockScreenCountdown(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(context.attributes.color.color.opacity(0.3))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.event(context.attributes.eventID))
        } dynamicIsland: { context in
            let attributes = context.attributes
            let state = context.state
            return DynamicIsland {
                // As in Apple's Timer: who and when on the left, the time left on the
                // right, the progress across the bottom; each kept off the rounded edges.
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        EventBadge(symbolName: attributes.symbolName, color: attributes.color, size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(attributes.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(state.target, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(state)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .fontDesign(.rounded)
                        .foregroundStyle(attributes.color.color)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progress(state)
                        .tint(attributes.color.color)
                        .padding(.horizontal, 6)
                        .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: attributes.symbolName)
                    .foregroundStyle(attributes.color.color)
            } compactTrailing: {
                timer(state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
                    .foregroundStyle(attributes.color.color)
            } minimal: {
                Image(systemName: attributes.symbolName)
                    .foregroundStyle(attributes.color.color)
            }
            .widgetURL(DeepLink.event(attributes.eventID))
            .keylineTint(attributes.color.color)
        }
    }

    private func timer(_ state: CountdownActivityAttributes.ContentState) -> Text {
        Text(timerInterval: min(Date.now, state.target)...state.target, countsDown: true)
    }

    private func progress(_ state: CountdownActivityAttributes.ContentState) -> some View {
        ProgressView(timerInterval: min(state.start, state.target)...state.target, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
    }
}

private struct LockScreenCountdown: View {
    let attributes: CountdownActivityAttributes
    let state: CountdownActivityAttributes.ContentState

    var body: some View {
        // The name and the time left on one line, the progress across the whole
        // width below: the timer gets all the room it needs and never wraps.
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                EventBadge(symbolName: attributes.symbolName, color: attributes.color, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(state.target, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(timerInterval: min(Date.now, state.target)...state.target, countsDown: true)
                    .font(.system(size: 28, weight: .heavy, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .fixedSize()
            }
            ProgressView(timerInterval: min(state.start, state.target)...state.target, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(attributes.color.color)
        }
        .padding(16)
    }
}
