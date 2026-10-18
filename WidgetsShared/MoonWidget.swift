import SwiftUI
import WidgetKit

/// Today's Moon: its phase, how much is lit and when it's next full — on the Home
/// Screen, the Lock Screen and as a Watch complication. Needs no place.
struct MoonWidget: Widget {
    static let kind = "MoonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MoonProvider()) { entry in
            MoonWidgetView(entry: entry)
        }
        .configurationDisplayName("common.moon")
        .description("widgets.todaysMoonPhaseAndThe")
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

nonisolated struct MoonEntry: TimelineEntry {
    let date: Date
    let moon: Astronomy.MoonState
    let nextFullMoon: Date
    /// Whether the last place found is south of the equator, where the Moon is lit the other way.
    let isSouthern: Bool

    init(date: Date, isSouthern: Bool = (WidgetComposition.sharedSettings.place?.latitude ?? 0) < 0) {
        self.date = date
        moon = Astronomy.moon(at: date)
        nextFullMoon = Astronomy.next(.fullMoon, after: date)
        self.isSouthern = isSouthern
    }
}

/// The Moon changes slowly: an entry every three hours for two days.
nonisolated struct MoonProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoonEntry {
        MoonEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (MoonEntry) -> Void) {
        completion(MoonEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoonEntry>) -> Void) {
        let now = Date.now
        let entries = (0..<16).map { MoonEntry(date: now.addingTimeInterval(Double($0) * 3 * 3600)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct MoonWidgetView: View {
    let entry: MoonEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(DeepLink.astronomy)
            .containerBackground(for: .widget) {
                if family.isSystem {
                    LinearGradient(
                        colors: [Color(red: 0.07, green: 0.09, blue: 0.22), Color(red: 0.2, green: 0.17, blue: 0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
    }

    private var lit: String {
        entry.moon.illumination.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "in 5 days", "Today".
    private var untilFull: String {
        CountdownText.relativeDays(Countdown(startDate: entry.nextFullMoon, isAllDay: false, recurrence: .never, now: entry.date, calendar: .autoupdatingCurrent))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    MoonPhaseView(entry.moon, isSouthern: entry.isSouthern, color: .primary)
                        .frame(width: 22, height: 22)
                        .widgetAccentable()
                    Text(verbatim: lit)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label {
                    Text(entry.moon.phase.name)
                } icon: {
                    MoonPhaseView(entry.moon, isSouthern: entry.isSouthern, color: .primary)
                        .frame(width: 16, height: 16)
                }
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
                Text("widgets.lit \(lit)")
                    .font(.caption)
                Text("widgets.fullMoon \(untilFull)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label {
                Text(verbatim: "\(String(localized: entry.moon.phase.name)) · \(lit)")
            } icon: {
                Image(systemName: entry.moon.phase.symbolName)
            }
        #if os(watchOS)
        case .accessoryCorner:
            MoonPhaseView(entry.moon, isSouthern: entry.isSouthern, color: .primary)
                .frame(width: 26, height: 26)
                .widgetLabel { Text(verbatim: lit) }
        #endif
        default:
            VStack(alignment: .leading, spacing: 2) {
                MoonPhaseView(entry.moon, isSouthern: entry.isSouthern)
                    .frame(width: 44, height: 44)
                    .shadow(color: .yellow.opacity(0.35), radius: 10)
                Spacer(minLength: 0)
                Text(entry.moon.phase.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("widgets.lit \(lit)")
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
                Text("widgets.fullMoon \(untilFull)")
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(.white)
        }
    }
}
