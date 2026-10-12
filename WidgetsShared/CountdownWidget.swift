import AppIntents
import SwiftUI
import WidgetKit

/// The countdown to one event — on the Home Screen, the Lock Screen, in StandBy
/// and as a Watch complication.
struct CountdownWidget: Widget {
    static let kind = "CountdownWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectEventIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("The time until or since an event.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #else
        [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct CountdownWidgetView: View {
    let entry: CountdownEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if let event = entry.event {
                content(event, countdown: event.countdown(at: entry.date))
                    .widgetURL(DeepLink.event(event.id))
            } else {
                emptyView
                    .widgetURL(DeepLink.newEvent)
            }
        }
        .containerBackground(for: .widget) {
            if let event = entry.event, renderingMode == .fullColor, family.isSystem {
                WidgetEventBackground(event: event)
            } else if family.isSystem {
                Rectangle().fill(.fill.secondary)
            }
        }
    }

    @ViewBuilder
    private func content(_ event: EventSnapshot, countdown: Countdown) -> some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(event: event, countdown: countdown)
        case .accessoryRectangular:
            AccessoryRectangularView(event: event, countdown: countdown)
        case .accessoryInline:
            Label {
                Text(verbatim: "\(event.title) · \(CountdownText.relativeDays(countdown))")
            } icon: {
                Image(systemName: event.symbolName)
            }
        #if os(watchOS)
        case .accessoryCorner:
            Text(countdown.isToday ? String(localized: "Today") : countdown.days.formatted())
                .font(.title2.weight(.bold))
                .widgetCurvesContent()
                .widgetLabel {
                    Text(event.title)
                }
        #else
        case .systemMedium:
            MediumCountdownView(event: event, countdown: countdown)
        #endif
        default:
            SmallCountdownView(event: event, countdown: countdown)
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        switch family {
        case .accessoryInline:
            Text("No Events")
        case .accessoryCircular:
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
        default:
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Add an event in Timity")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

extension WidgetFamily {
    var isSystem: Bool {
        #if os(watchOS)
        false
        #else
        switch self {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: true
        default: false
        }
        #endif
    }
}

/// The big number: days to go, "Today", or a live timer in the last hours.
struct WidgetCountdownNumber: View {
    let countdown: Countdown
    let size: CGFloat

    var body: some View {
        if countdown.isToday {
            if countdown.direction == .future, !countdown.isAllDay {
                Text(timerInterval: countdown.now...countdown.target, countsDown: true, showsHours: true)
                    .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text("Today")
                    .font(.system(size: size * 0.7, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        } else {
            Text(countdown.days, format: .number)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: countdown.direction == .future))
        }
    }
}

private struct SmallCountdownView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: event.symbolName)
                .font(.title3.weight(.semibold))
                .widgetAccentable()
            Spacer(minLength: 0)
            WidgetCountdownNumber(countdown: countdown, size: 50)
                .widgetAccentable()
            if !countdown.isToday {
                Text(CountdownText.dayCaption(countdown))
                    .font(.caption.weight(.semibold))
                    .opacity(0.85)
            }
            Text(event.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
    }
}

private struct MediumCountdownView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        let parts = countdown.breakdown(includeWeeks: true).parts(includingSeconds: false).prefix(4)

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: event.symbolName)
                    .font(.title3.weight(.semibold))
                    .widgetAccentable()
                Spacer(minLength: 0)
                WidgetCountdownNumber(countdown: countdown, size: 56)
                    .widgetAccentable()
                if !countdown.isToday {
                    Text(CountdownText.dayCaption(countdown))
                        .font(.caption.weight(.semibold))
                        .opacity(0.85)
                }
            }
            .frame(maxHeight: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(countdown.targetText)
                    .font(.caption)
                    .opacity(0.85)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if !countdown.isToday {
                    HStack(spacing: 6) {
                        ForEach(Array(parts)) { part in
                            VStack(spacing: 0) {
                                Text(part.value, format: .number)
                                    .font(.headline.monospacedDigit())
                                Text(CountdownText.unit(part.unit, value: part.value))
                                    .font(.system(size: 9, weight: .semibold))
                                    .textCase(.uppercase)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.18), in: .rect(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(.white)
    }
}

private struct AccessoryCircularView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: event.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                if countdown.isToday {
                    Text("Today")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                } else {
                    Text(countdown.days, format: .number)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    Text(CountdownText.unit(.day, value: countdown.days))
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AccessoryRectangularView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(event.title, systemImage: event.symbolName)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(CountdownText.relativeDays(countdown))
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(countdown.target, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// An event's photo or colour behind a widget.
struct WidgetEventBackground: View {
    let event: EventSnapshot

    var body: some View {
        if let image = ImageProcessing.image(from: event.imageData, maxPixelSize: 700) {
            image
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
        } else {
            event.color.gradient
        }
    }
}
