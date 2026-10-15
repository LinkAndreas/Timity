import SwiftUI
import WidgetKit

/// The next few events at a glance.
struct UpcomingWidget: Widget {
    static let kind = "UpcomingWidget"

    let events: any EventReader

    init(events: any EventReader) {
        self.events = events
    }

    init() {
        self.init(events: WidgetComposition.reader)
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: UpcomingProvider(events: events)) { entry in
            UpcomingWidgetView(entry: entry)
        }
        .configurationDisplayName("widgets.upNext")
        .description("widgets.yourNextEventsAndThe")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular]
        #else
        [.systemMedium, .systemLarge, .accessoryRectangular]
        #endif
    }
}

struct UpcomingWidgetView: View {
    let entry: UpcomingEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.events.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.tint)
                    Text("widgets.addAnEventInTimity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .widgetURL(DeepLink.newEvent)
            } else if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.events.prefix(3)) { event in
                        HStack(spacing: 4) {
                            Image(systemName: event.symbolName)
                                .font(.caption2)
                                .widgetAccentable()
                            Text(event.title)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(shortDays(event.countdown(at: entry.date)))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
                    Text("widgets.upNext")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(entry.events.prefix(isLarge ? 6 : 3)) { event in
                        Link(destination: DeepLink.event(event.id)) {
                            UpcomingRow(event: event, countdown: event.countdown(at: entry.date), isLarge: isLarge)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var isLarge: Bool {
        #if os(watchOS)
        false
        #else
        family == .systemLarge
        #endif
    }

    /// "12d", or "Today", for the tight rectangular complication.
    private func shortDays(_ countdown: Countdown) -> String {
        countdown.isToday
            ? String(localized: "common.today")
            : Duration.seconds(Double(countdown.days) * 86_400).formatted(.units(allowed: [.days], width: .narrow))
    }
}

private struct UpcomingRow: View {
    let event: EventSnapshot
    let countdown: Countdown
    let isLarge: Bool

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 10) {
            if renderingMode == .fullColor {
                EventBadge(symbolName: event.symbolName, color: event.color, size: isLarge ? 38 : 30)
            } else {
                Image(systemName: event.symbolName)
                    .frame(width: isLarge ? 38 : 30)
                    .widgetAccentable()
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(isLarge ? .headline : .subheadline.weight(.semibold))
                    .lineLimit(1)
                if isLarge {
                    Text(countdown.targetText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Text(CountdownText.relativeDays(countdown))
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(event.color.color) : AnyShapeStyle(.primary))
                .widgetAccentable()
        }
    }
}
