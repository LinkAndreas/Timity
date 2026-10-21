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
        #elseif os(macOS)
        // The Mac has no Lock Screen or complications.
        [.systemMedium, .systemLarge]
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
            } else if isRectangularAccessory, entry.events.count == 1, let event = entry.events.first {
                // A single event fills the rectangle as the countdown does, rather than one small
                // row in an empty box.
                AccessoryRectangularView(event: event, countdown: event.countdown(at: entry.date))
                    .widgetURL(DeepLink.event(event.id))
            } else if isRectangularAccessory {
                UpcomingRectangularView(events: Array(entry.events.prefix(3)), date: entry.date)
            } else {
                VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
                    Text("widgets.upNext")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)
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

    /// The Lock Screen's or a complication's rectangle, which the Mac doesn't have.
    private var isRectangularAccessory: Bool {
        #if os(macOS)
        false
        #else
        family == .accessoryRectangular
        #endif
    }

    private var isLarge: Bool {
        #if os(watchOS)
        false
        #else
        family == .systemLarge
        #endif
    }
}

/// The next three events in a rectangle, a row each: the symbol in the event's colour where the
/// widget is in full colour, so each row is told apart at a glance.
private struct UpcomingRectangularView: View {
    let events: [EventSnapshot]
    let date: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        // Fewer than three events spread over the rectangle rather than bunching at its top.
        VStack(alignment: .leading, spacing: events.count < 3 ? 10 : 3) {
            ForEach(events) { event in
                let countdown = event.countdown(at: date)
                HStack(spacing: 6) {
                    Image(systemName: event.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint(event))
                        .frame(width: 18)
                        .widgetAccentable()
                    Text(event.title)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    // In the text colour: a dark event colour on the dark rectangle would hardly show.
                    Text(shortDays(countdown))
                        .font(.footnote.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .widgetAccentable()
                }
                // "Trip to Lisbon, in 12 days" rather than the narrow "12d".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(event.title))
                .accessibilityValue(Text(CountdownText.relativeDays(countdown)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func tint(_ event: EventSnapshot) -> AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(event.color.color) : AnyShapeStyle(.primary)
    }

    /// "12d", or "Today", for the tight rectangle.
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
        .accessibilityElement(children: .combine)
    }
}
