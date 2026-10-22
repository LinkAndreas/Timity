import AppIntents
import SwiftUI
import WidgetKit

/// The countdown to one event — on the Home Screen, the Lock Screen, in StandBy
/// and as a Watch complication.
struct CountdownWidget: Widget {
    static let kind = "CountdownWidget"

    let events: any EventReader

    init(events: any EventReader) {
        self.events = events
    }

    init() {
        self.init(events: WidgetComposition.reader)
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectEventIntent.self, provider: CountdownProvider(events: events)) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("common.countdown")
        .description("widgets.theTimeUntilOrSince")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #elseif os(macOS)
        // The Mac has no Lock Screen or complications.
        [.systemSmall, .systemMedium, .systemLarge]
        #else
        [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
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
                CountdownWidgetContent(event: event, countdown: event.countdown(at: entry.date))
                    .widgetURL(DeepLink.event(event.id))
            } else {
                CountdownWidgetEmpty()
                    .widgetURL(DeepLink.newEvent)
            }
        }
        .containerBackground(for: .widget) {
            if let event = entry.event, renderingMode == .fullColor, family.isSystem || family.isSmartStack {
                WidgetEventBackground(event: event)
            } else if family.isSystem {
                Rectangle().fill(.fill.secondary)
            }
        }
    }
}

/// The event at the widget's size.
private struct CountdownWidgetContent: View {
    let event: EventSnapshot
    let countdown: Countdown

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(event: event, countdown: countdown)
        case .accessoryRectangular:
            AccessoryRectangularView(event: event, countdown: countdown)
        case .accessoryInline:
            Label {
                // The count first, so a long name is what gets cut short.
                Text(verbatim: "\(CountdownText.relativeDays(countdown)) · \(event.title)")
            } icon: {
                Image(systemName: event.symbolName)
            }
        #if os(watchOS)
        case .accessoryCorner:
            Text(countdown.isToday ? String(localized: "common.today") : countdown.days.formatted())
                .font(.title2.weight(.bold))
                .widgetCurvesContent()
                .widgetLabel {
                    Text(event.title)
                }
        #else
        case .systemMedium:
            MediumCountdownView(event: event, countdown: countdown)
        case .systemLarge:
            LargeCountdownView(event: event, countdown: countdown)
        #endif
        default:
            SmallCountdownView(event: event, countdown: countdown)
        }
    }
}

/// What the widget shows before there's an event.
private struct CountdownWidgetEmpty: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("common.noEvents")
        case .accessoryCircular:
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label("common.noEvents", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .widgetAccentable()
                Text("widgets.addAnEventInTimity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: "calendar.badge.plus")
                .font(.title3)
                .widgetLabel { Text("common.noEvents") }
        #endif
        default:
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("widgets.addAnEventInTimity")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

nonisolated extension Countdown {
    /// Whether the moment is later today, so a timer can count down to it.
    var isLiveToday: Bool {
        isToday && direction == .future && !isAllDay
    }
}

nonisolated extension WidgetFamily {
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
            if countdown.isLiveToday {
                Text(timerInterval: countdown.now...countdown.target, countsDown: true, showsHours: true)
                    .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text("common.today")
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
                .accessibilityHidden(true)
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
            if let progress = countdown.progress, countdown.direction == .future {
                WidgetProgressBar(progress: progress)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .widgetTextShadow(for: event)
        // One element: "Trip to Lisbon, 12, days to go".
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(event.title))
    }
}

private struct MediumCountdownView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        if showsTimer {
            MediumTimerLayout(event: event, countdown: countdown)
        } else {
            MediumDaysLayout(event: event, countdown: countdown)
        }
    }

    /// In its last hours a timed event's live timer, which takes all the room beside it: the
    /// name and date across the top instead, and the time below them across the whole width.
    private var showsTimer: Bool {
        countdown.isToday && countdown.direction == .future && !countdown.isAllDay
    }
}

/// A timed event's last hours: the name and date across the top, the live timer below them.
private struct MediumTimerLayout: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: event.symbolName)
                    .accessibilityHidden(true)
                    .font(.title3.weight(.semibold))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(countdown.targetText)
                        .font(.caption)
                        .opacity(0.85)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetEventButtons(event: event, countdown: countdown)
            }
            Spacer(minLength: 0)
            WidgetCountdownNumber(countdown: countdown, size: 72)
                .widgetAccentable()
            if let progress = countdown.progress {
                WidgetProgressBar(progress: progress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .widgetTextShadow(for: event)
    }
}

/// The days beside the name, the date and each unit.
private struct MediumDaysLayout: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        // Three units, so each one's name fits beside the big number: the largest ones say enough.
        let parts = countdown.breakdown(includeWeeks: true).parts(includingSeconds: false).prefix(3)

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: event.symbolName)
                    .accessibilityHidden(true)
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
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 6) {
                // The date right under the name, both beside the buttons, so the taller buttons
                // don't push the date down.
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(countdown.targetText)
                            .font(.caption)
                            .opacity(0.85)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    WidgetEventButtons(event: event, countdown: countdown)
                }
                Spacer(minLength: 0)
                if let progress = countdown.progress, countdown.direction == .future {
                    WidgetProgressBar(progress: progress)
                }
                if !countdown.isToday {
                    HStack(spacing: 6) {
                        ForEach(Array(parts)) { part in
                            VStack(spacing: 0) {
                                Text(part.value, format: .number)
                                    .font(.headline.monospacedDigit())
                                Text(CountdownText.unit(part.unit, value: part.value))
                                    .font(.system(size: 10, weight: .semibold))
                                    .textCase(.uppercase)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)
                            .background(.white.opacity(0.18), in: .rect(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(.white)
        .widgetTextShadow(for: event)
    }
}

/// The large size: the name and date on top, the big number, every unit of the
/// span, and the progress when the event shows it.
private struct LargeCountdownView: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        let parts = countdown.breakdown(includeWeeks: true).parts(includingSeconds: false).prefix(4)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: event.symbolName)
                    .accessibilityHidden(true)
                    .font(.title2.weight(.semibold))
                    .widgetAccentable()
                Spacer()
                WidgetEventButtons(event: event, countdown: countdown)
            }
            Text(event.title)
                .font(.title2.weight(.bold))
                .lineLimit(2)
            Text(countdown.targetText)
                .font(.subheadline.weight(.medium))
                .opacity(0.9)
                .lineLimit(1)
            Spacer(minLength: 0)
            WidgetCountdownNumber(countdown: countdown, size: 96)
                .widgetAccentable()
            if !countdown.isToday {
                Text(CountdownText.dayCaption(countdown))
                    .font(.headline)
                    .opacity(0.9)
                HStack(spacing: 8) {
                    ForEach(Array(parts)) { part in
                        VStack(spacing: 0) {
                            Text(part.value, format: .number)
                                .font(.title3.weight(.bold).monospacedDigit())
                            Text(CountdownText.unit(part.unit, value: part.value))
                                .font(.system(size: 10, weight: .semibold))
                                .textCase(.uppercase)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.22), in: .rect(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            if let progress = countdown.progress, countdown.direction == .future {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetProgressBar(progress: progress, height: 8)
                    Text("common.ofTheWaitIsOver \(progress.formatted(.percent.precision(.fractionLength(0))))")
                        .font(.caption.weight(.semibold))
                        .opacity(0.9)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .widgetTextShadow(for: event)
    }
}

/// How much of the wait has passed, as a white bar on the widget's colour or photo.
struct WidgetProgressBar: View {
    let progress: Double
    var height: CGFloat = 5

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white)
                        .frame(width: progress > 0 ? max(height, proxy.size.width * progress) : 0)
                }
            }
            .frame(height: height)
            .widgetAccentable()
            .accessibilityElement()
            .accessibilityLabel(Text("common.ofTheWaitIsOver \(progress.formatted(.percent.precision(.fractionLength(0))))"))
    }
}

extension View {
    /// A soft shadow behind white text when the event's photo is behind it.
    func widgetTextShadow(for event: EventSnapshot) -> some View {
        shadow(color: .black.opacity(event.imageData == nil ? 0 : 0.5), radius: event.imageData == nil ? 0 : 4, y: 1)
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
                    .accessibilityHidden(true)
                    .font(.system(size: 11, weight: .semibold))
                if countdown.isLiveToday {
                    // The hours and minutes left on the day itself, as on the Lock Screen.
                    Text(timerInterval: countdown.now...countdown.target, countsDown: true, showsHours: true)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                } else if countdown.isToday {
                    Text("common.today")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                } else {
                    Text(countdown.days, format: .number)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    // "Days ago" for one behind, so it doesn't read as days to go.
                    Text(countdown.direction == .past ? CountdownText.dayCaption(countdown) : CountdownText.unit(.day, value: countdown.days))
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(4)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The event in a rectangle: the day count large, the way it's read at a glance, beside the
/// symbol, name and date, and the wait's progress along the bottom. On the Watch's Smart Stack it
/// sits on the event's colour; on a face the system tints it.
struct AccessoryRectangularView: View {
    let event: EventSnapshot
    let countdown: Countdown

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                RectangularCountdownNumber(countdown: countdown)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Label {
                        Text(event.title)
                            .lineLimit(2)
                            // Two lines where the name needs them, rather than cut short on one.
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: event.symbolName)
                    }
                    .font(.headline)
                    .labelStyle(RectangularTitleLabelStyle())
                    Text(countdown.target, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let progress = countdown.progress, countdown.direction == .future {
                Gauge(value: progress) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(renderingMode == .fullColor ? .white : nil)
                .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var secondary: AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary)
    }
}

/// The days left large, with their caption below; the live timer on the day itself.
private struct RectangularCountdownNumber: View {
    let countdown: Countdown

    var body: some View {
        VStack(alignment: .leading, spacing: -3) {
            if countdown.isLiveToday {
                Text(timerInterval: countdown.now...countdown.target, countsDown: true, showsHours: true)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 74, alignment: .leading)
            } else if countdown.isToday {
                Text("common.today")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
            } else {
                Text(countdown.days, format: .number)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                // Small, so the number's column stays as narrow as the number and the name has room.
                Text(CountdownText.dayCaption(countdown))
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.85)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The symbol above the name, so a long name has the row's whole width for two lines.
private struct RectangularTitleLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.icon
                .font(.footnote.weight(.semibold))
                .widgetAccentable()
            configuration.title
                .font(.footnote.weight(.semibold))
        }
    }
}

nonisolated extension WidgetFamily {
    /// The Watch's Smart Stack rectangle, which shows the widget's own background; on a face
    /// the system removes it.
    var isSmartStack: Bool {
        #if os(watchOS)
        self == .accessoryRectangular
        #else
        false
        #endif
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
                    // As in the app: dark enough throughout for white text, darker at the edges.
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.45), location: 0),
                            .init(color: .black.opacity(0.3), location: 0.4),
                            .init(color: .black.opacity(0.65), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        } else {
            event.color.gradient
        }
    }
}

/// Buttons that act without opening the app: pin, and start a counter over.
struct WidgetEventButtons: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        HStack(spacing: 6) {
            // A past one-off event is a "since" counter that can start over.
            if event.recurrence == .never, countdown.direction == .past {
                Button(intent: StartOverIntent(eventID: event.id)) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel(Text("common.startOver"))
            }
            Button(intent: TogglePinIntent(eventID: event.id)) {
                Image(systemName: event.isPinned ? "pin.fill" : "pin")
            }
            .accessibilityLabel(event.isPinned ? Text("common.unpin") : Text("common.pin"))
        }
        .font(.caption.weight(.bold))
        .buttonStyle(.plain)
        .padding(6)
        .background(.white.opacity(0.2), in: .capsule)
    }
}
