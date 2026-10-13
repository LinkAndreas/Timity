import SwiftUI
import WidgetKit

/// Every week of a life on the Home Screen, from the birthday set in Timity.
struct LifeInWeeksWidget: Widget {
    static let kind = WidgetKind.lifeInWeeks.rawValue

    let birthday: () -> Date?
    let lifeExpectancy: () -> Int

    init(birthday: @escaping () -> Date?, lifeExpectancy: @escaping () -> Int) {
        self.birthday = birthday
        self.lifeExpectancy = lifeExpectancy
    }

    init() {
        self.init(
            birthday: { WidgetComposition.sharedSettings.birthday },
            lifeExpectancy: { WidgetComposition.sharedSettings.lifeExpectancy }
        )
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LifeInWeeksProvider(birthday: birthday, lifeExpectancy: lifeExpectancy)) { entry in
            LifeInWeeksWidgetView(entry: entry)
        }
        .configurationDisplayName("Life in Weeks")
        .description("Every week of your life, one dot each.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

struct LifeInWeeksEntry: TimelineEntry {
    let date: Date
    let birthday: Date?
    let years: Int
}

struct LifeInWeeksProvider: TimelineProvider {
    let birthday: () -> Date?
    let lifeExpectancy: () -> Int

    func placeholder(in context: Context) -> LifeInWeeksEntry {
        LifeInWeeksEntry(date: .now, birthday: Calendar.autoupdatingCurrent.date(byAdding: .year, value: -33, to: .now), years: 90)
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeInWeeksEntry) -> Void) {
        completion(entry(at: .now, preview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeInWeeksEntry>) -> Void) {
        // A new dot fills once a week; a daily refresh is plenty.
        let tomorrow = WidgetSchedule.midnights(count: 1).first ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: .now, preview: false)], policy: .after(tomorrow)))
    }

    private func entry(at date: Date, preview: Bool) -> LifeInWeeksEntry {
        let sample = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -33, to: .now)
        return LifeInWeeksEntry(date: date, birthday: birthday() ?? (preview ? sample : nil), years: lifeExpectancy())
    }
}

struct LifeInWeeksWidgetView: View {
    let entry: LifeInWeeksEntry

    var body: some View {
        Group {
            if let birthday = entry.birthday {
                let life = LifeInWeeks(birth: birthday, now: entry.date, expectedYears: entry.years)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Life in Weeks")
                            .font(.headline)
                        Spacer()
                        Text("Week \(life.weeksLived.formatted())")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.tint)
                            .widgetAccentable()
                    }
                    LifeInWeeksGrid(life: life, color: .accentColor)
                }
                .widgetURL(DeepLink.lifeInWeeks)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Set your birthday in Timity › Calculate › Life in Weeks.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
