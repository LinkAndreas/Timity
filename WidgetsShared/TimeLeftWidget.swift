import SwiftUI
import WidgetKit

/// How much of today, this week, this month and this year is left, as rings.
struct TimeLeftWidget: Widget {
    static let kind = "TimeLeftWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TimeLeftProvider()) { entry in
            TimeLeftWidgetView(entry: entry)
        }
        .configurationDisplayName("widgets.timeLeft")
        .description("widgets.howMuchOfTheDay")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryRectangular, .accessoryCircular]
        #else
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular]
        #endif
    }
}

nonisolated struct TimeLeftEntry: TimelineEntry {
    let date: Date
}

nonisolated struct TimeLeftProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimeLeftEntry { TimeLeftEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (TimeLeftEntry) -> Void) {
        completion(TimeLeftEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeLeftEntry>) -> Void) {
        // Every quarter of an hour for the next six hours; the day ring moves the most.
        let start = Date.now
        let entries = (0..<24).map { TimeLeftEntry(date: start.addingTimeInterval(Double($0) * 900)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TimeLeftWidgetView: View {
    let entry: TimeLeftEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                // The year on its own: the ring that changes least, read at a glance.
                let year = PeriodProgress.progress(of: .year, at: entry.date)
                Gauge(value: 1 - year.elapsed) {
                    Text("common.year")
                } currentValueLabel: {
                    Text((1 - year.elapsed).formatted(.percent.precision(.fractionLength(0))))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(PeriodProgress.Period.allCases) { period in
                        let progress = PeriodProgress.progress(of: period, at: entry.date)
                        HStack(spacing: 6) {
                            Text(TimeLeftWidgetView.name(period))
                                .font(.caption2.weight(.semibold))
                                .frame(width: 44, alignment: .leading)
                            ProgressView(value: 1 - progress.elapsed)
                                .widgetAccentable()
                        }
                    }
                }
            default:
                HStack(spacing: 10) {
                    ForEach(PeriodProgress.Period.allCases) { period in
                        TimeLeftRing(period: period, progress: PeriodProgress.progress(of: period, at: entry.date), isLarge: !isSmall)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var isSmall: Bool {
        #if os(watchOS)
        true
        #else
        family == .systemSmall
        #endif
    }

    static func name(_ period: PeriodProgress.Period) -> LocalizedStringKey {
        switch period {
        case .day: "widgets.day"
        case .week: "common.week2"
        case .month: "common.month"
        case .year: "common.year"
        }
    }
}

/// One period as a ring of what's left, with its name and percentage.
private struct TimeLeftRing: View {
    let period: PeriodProgress.Period
    let progress: PeriodProgress.Progress
    let isLarge: Bool

    var body: some View {
        let left = 1 - progress.elapsed
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: isLarge ? 7 : 5)
                Circle()
                    .trim(from: 0, to: left)
                    .stroke(color, style: StrokeStyle(lineWidth: isLarge ? 7 : 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                Text(left.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: isLarge ? 13 : 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            if isLarge {
                Text(TimeLeftWidgetView.name(period))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch period {
        case .day: .orange
        case .week: .pink
        case .month: .purple
        case .year: .blue
        }
    }
}
