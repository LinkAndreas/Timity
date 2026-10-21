import SwiftUI
import WidgetKit

/// The next sunrise, golden hour or sunset where the user last was.
struct SunWidget: Widget {
    static let kind = WidgetKind.sun.rawValue

    /// The place the app or the Watch found last.
    let place: () -> Place?

    init(place: @escaping () -> Place?) {
        self.place = place
    }

    init() {
        self.init(place: { WidgetComposition.sharedSettings.place })
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SunProvider(place: place)) { entry in
            SunWidgetView(entry: entry)
        }
        .configurationDisplayName("common.sun")
        .description("widgets.theTimeToTheNext")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #elseif os(macOS)
        // The Mac has no Lock Screen or complications.
        [.systemSmall]
        #else
        [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

nonisolated struct SunEvent: Hashable, Sendable {
    nonisolated enum Kind: Sendable {
        case sunrise, goldenHour, sunset
    }

    let kind: Kind
    let date: Date

    var symbolName: String {
        switch kind {
        case .sunrise: "sunrise.fill"
        case .goldenHour: "camera.filters"
        case .sunset: "sunset.fill"
        }
    }

    var name: LocalizedStringKey {
        switch kind {
        case .sunrise: "common.sunrise"
        case .goldenHour: "common.goldenHour"
        case .sunset: "common.sunset"
        }
    }
}

nonisolated struct SunEntry: TimelineEntry {
    let date: Date
    /// The next sun event, or `nil` before the app has found a location.
    let next: SunEvent?
}

nonisolated struct SunProvider: TimelineProvider {
    let place: () -> Place?

    func placeholder(in context: Context) -> SunEntry {
        SunEntry(date: .now, next: SunEvent(kind: .sunset, date: .now.addingTimeInterval(2 * 3600)))
    }

    func getSnapshot(in context: Context, completion: @escaping (SunEntry) -> Void) {
        let events = Self.events(at: place(), after: .now)
        completion(SunEntry(date: .now, next: events.first ?? (context.isPreview ? placeholder(in: context).next : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunEntry>) -> Void) {
        let now = Date.now
        let events = Self.events(at: place(), after: now)
        // An entry now and at each event, when the next one takes over.
        var entries = [SunEntry(date: now, next: events.first)]
        for (index, event) in events.enumerated() where index + 1 < events.count {
            entries.append(SunEntry(date: event.date, next: events[index + 1]))
        }
        completion(Timeline(entries: entries, policy: .after(events.last?.date ?? now.addingTimeInterval(6 * 3600))))
    }

    /// Sunrises, evening golden hours and sunsets over the next two days.
    static func events(at place: Place?, after date: Date) -> [SunEvent] {
        guard let place else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        return (0...2).flatMap { offset -> [SunEvent] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { return [] }
            let sun = SolarCalculator.day(containing: day, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
            return [
                sun.sunrise.map { SunEvent(kind: .sunrise, date: $0) },
                sun.goldenHourEveningStart.map { SunEvent(kind: .goldenHour, date: $0) },
                sun.sunset.map { SunEvent(kind: .sunset, date: $0) },
            ].compactMap { $0 }
        }
        .filter { $0.date > date }
        .sorted { $0.date < $1.date }
    }
}

struct SunWidgetView: View {
    let entry: SunEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let next = entry.next {
                // One element, read as "Sunset, 18:55, in 3 hours".
                SunWidgetContent(next: next)
                    .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "location.slash")
                    Text("widgets.openTheSunTabIn")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(for: .widget) {
            if family.isSystem || family.isSmartStack {
                LinearGradient(colors: [Color(red: 1, green: 0.6, blue: 0.3), Color(red: 0.35, green: 0.3, blue: 0.75)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// The next sunrise or sunset at the widget's size.
private struct SunWidgetContent: View {
    let next: SunEvent

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let time = next.date.formatted(date: .omitted, time: .shortened)
        switch family {
        case .accessoryInline:
            Label {
                Text("\(time) \(Text(next.name))")
            } icon: {
                Image(systemName: next.symbolName)
            }
        case .accessoryCircular:
            // On a disc, as the countdown's and the moon's are, so the three sit alike on a face.
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: next.symbolName)
                        .font(.caption)
                    Text(time)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
                .padding(4)
                .widgetAccentable()
            }
            // The symbol alone doesn't say whether it's sunrise or sunset.
            .accessibilityLabel(Text(next.name))
            .accessibilityValue(Text(time))
        case .accessoryRectangular:
            SunRectangularView(next: next, time: time)
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: next.symbolName)
                .font(.title3)
                .widgetLabel { Text(time) }
                .accessibilityLabel(Text(next.name))
                .accessibilityValue(Text(time))
        #endif
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: next.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                Spacer(minLength: 0)
                Text(next.name)
                    .font(.headline)
                Text(time)
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                Text(next.date, style: .relative)
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

/// The next sunrise or sunset in a rectangle: its symbol in colour beside the time, large, with
/// its name above and how long until it below.
private struct SunRectangularView: View {
    let next: SunEvent
    let time: String

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: next.symbolName)
                .font(.system(size: 30, weight: .semibold))
                .symbolRenderingMode(renderingMode == .fullColor ? .multicolor : .hierarchical)
                .widgetAccentable()
                .frame(width: 40)
            VStack(alignment: .leading, spacing: -1) {
                Text(next.name)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.85)
                Text(time)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(next.date, style: .relative)
                    .font(.caption2)
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
