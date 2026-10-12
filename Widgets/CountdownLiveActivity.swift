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
                DynamicIslandExpandedRegion(.leading) {
                    EventBadge(symbolName: attributes.symbolName, color: attributes.color, size: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(state)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .fontDesign(.rounded)
                        .foregroundStyle(attributes.color.color)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progress(state)
                        .tint(attributes.color.color)
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
        HStack(spacing: 14) {
            EventBadge(symbolName: attributes.symbolName, color: attributes.color, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.target, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(timerInterval: min(state.start, state.target)...state.target, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(attributes.color.color)
            }
            Text(timerInterval: min(Date.now, state.target)...state.target, countsDown: true)
                .font(.system(size: 30, weight: .heavy, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120, alignment: .trailing)
        }
        .padding(16)
    }
}
