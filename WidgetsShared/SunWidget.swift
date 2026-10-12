import SwiftUI
import WidgetKit

/// The next sunrise, golden hour or sunset where the user last was.
struct SunWidget: Widget {
    static let kind = "SunWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SunProvider()) { entry in
            SunWidgetView(entry: entry)
        }
        .configurationDisplayName("Sun")
        .description("The time to the next sunrise, golden hour or sunset.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        [.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct SunEvent: Hashable, Sendable {
    enum Kind: Sendable {
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
        case .sunrise: "Sunrise"
        case .goldenHour: "Golden Hour"
        case .sunset: "Sunset"
        }
    }
}

struct SunEntry: TimelineEntry {
    let date: Date
    /// The next sun event, or `nil` before the app has found a location.
    let next: SunEvent?
}

struct SunProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunEntry {
        SunEntry(date: .now, next: SunEvent(kind: .sunset, date: .now.addingTimeInterval(2 * 3600)))
    }

    func getSnapshot(in context: Context, completion: @escaping (SunEntry) -> Void) {
        let events = Self.events(after: .now)
        completion(SunEntry(date: .now, next: events.first ?? (context.isPreview ? placeholder(in: context).next : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunEntry>) -> Void) {
        let now = Date.now
        let events = Self.events(after: now)
        // An entry now and at each event, when the next one takes over.
        var entries = [SunEntry(date: now, next: events.first)]
        for (index, event) in events.enumerated() where index + 1 < events.count {
            entries.append(SunEntry(date: event.date, next: events[index + 1]))
        }
        completion(Timeline(entries: entries, policy: .after(events.last?.date ?? now.addingTimeInterval(6 * 3600))))
    }

    /// Sunrises, evening golden hours and sunsets over the next two days.
    static func events(after date: Date) -> [SunEvent] {
        guard let place = SharedSettings.place else { return [] }
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
                content(next)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "location.slash")
                    Text("Open the Sun tab in Timity")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(for: .widget) {
            if family.isSystem {
                LinearGradient(colors: [Color(red: 1, green: 0.6, blue: 0.3), Color(red: 0.35, green: 0.3, blue: 0.75)], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    @ViewBuilder
    private func content(_ next: SunEvent) -> some View {
        let time = next.date.formatted(date: .omitted, time: .shortened)
        switch family {
        case .accessoryInline:
            Label {
                Text(verbatim: "\(time) ") + Text(next.name)
            } icon: {
                Image(systemName: next.symbolName)
            }
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: next.symbolName)
                    .font(.caption)
                Text(time)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(next.name, systemImage: next.symbolName)
                    .font(.headline)
                    .widgetAccentable()
                Text(time)
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(next.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: next.symbolName)
                .font(.title3)
                .widgetLabel { Text(time) }
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
