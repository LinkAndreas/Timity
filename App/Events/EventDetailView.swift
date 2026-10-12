import SwiftData
import SwiftUI
import WidgetKit

/// One event: a live countdown over its colour or photo, then the span in every
/// unit and the details of the date.
struct EventDetailView: View {
    @Bindable var event: Event
    let onEdit: () -> Void
    /// Closes the page and deletes the event.
    let onDelete: () -> Void

    @Environment(AppSettings.self) private var settings
    @State private var isConfirmingDelete = false
    @State private var isConfirmingStartOver = false
    @State private var isAddingToCalendar = false
    @State private var shareImage: Image?
    @State private var isLiveActivityRunning = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: settings.showsSeconds ? 1 : 60)) { context in
            let countdown = event.snapshot.countdown(at: context.date)

            ScrollView {
                VStack(spacing: 16) {
                    CountdownHero(event: event, countdown: countdown, showsWeeks: settings.showsWeeks, showsSeconds: settings.showsSeconds)
                    if LiveActivityController.canStart(for: countdown, now: context.date) || isLiveActivityRunning {
                        liveActivityButton(countdown: countdown)
                    }
                    ChecklistCard(event: event)
                    TotalsCard(countdown: countdown, tint: event.color.color)
                    if !event.resetHistory.isEmpty {
                        StreakCard(event: event, now: context.date)
                    }
                    if !event.isYearUnknown {
                        MilestonesCard(event: event, now: context.date, tint: event.color.color)
                    }
                    DateDetailsCard(event: event, countdown: countdown)
                    if !event.notes.isEmpty {
                        Card(title: "Notes") {
                            Text(event.notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .background {
            // A wash of the event's colour behind the cards.
            LinearGradient(
                colors: [event.color.color.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: onEdit)
                    .keyboardShortcut("e")
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(event.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
                    event.isPinned.toggle()
                    event.modifiedAt = .now
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(event.title, image: shareImage)) {
                        Label("Share as Image", systemImage: "photo")
                    }
                }
                ShareLink(item: EventShareText.text(for: event)) {
                    Label("Share as Text", systemImage: "text.quote")
                }
                ShareLink(item: EventFileTransfer(event: event), preview: SharePreview(event.title)) {
                    Label("Send a Copy", systemImage: "paperplane")
                }
                Button("Add to Calendar", systemImage: "calendar.badge.plus") {
                    isAddingToCalendar = true
                }
                if event.recurrence == .never, event.startDate() < .now {
                    Button("Start Over", systemImage: "arrow.counterclockwise") {
                        isConfirmingStartOver = true
                    }
                }
                Button(event.isArchived ? LocalizedStringKey("Unarchive") : LocalizedStringKey("Archive"),
                       systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
                    event.isArchived.toggle()
                    event.modifiedAt = .now
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: event.isPinned)
        // The share picture changes once a day, with the day count.
        .task(id: "\(event.snapshot.countdown().days)-\(event.modifiedAt.timeIntervalSince1970)") {
            shareImage = ShareCard.image(for: event, countdown: event.snapshot.countdown())
            isLiveActivityRunning = LiveActivityController.isRunning(for: event.id)
        }
        .sheet(isPresented: $isAddingToCalendar) {
            AddToCalendarSheet(event: event)
                .ignoresSafeArea()
        }
        .confirmationDialog("Start Over?", isPresented: $isConfirmingStartOver, titleVisibility: .visible) {
            Button("Start Over from Now") {
                withAnimation { event.startOver() }
                WidgetCenter.shared.reloadAllTimelines()
            }
        } message: {
            Text("The count starts again from now. Your previous streaks are kept.")
        }
        .confirmationDialog("Delete Event?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete “\(event.title)”", role: .destructive, action: onDelete)
        } message: {
            Text("The event is deleted on all your devices.")
        }
    }
}

extension EventDetailView {
    /// Puts the last hours on the Lock Screen and in the Dynamic Island.
    fileprivate func liveActivityButton(countdown: Countdown) -> some View {
        Button {
            if isLiveActivityRunning {
                Task { await LiveActivityController.end(for: event.id) }
            } else {
                LiveActivityController.start(for: event, target: countdown.target)
            }
            withAnimation { isLiveActivityRunning.toggle() }
        } label: {
            Label(
                isLiveActivityRunning ? LocalizedStringKey("Remove from Lock Screen") : LocalizedStringKey("Show on Lock Screen"),
                systemImage: isLiveActivityRunning ? "lock.slash" : "lock.rectangle.on.rectangle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .sensoryFeedback(.success, trigger: isLiveActivityRunning)
    }
}

/// The large countdown at the top of an event: the days, the occurrence, and
/// every unit of the span on glass.
struct CountdownHero: View {
    let event: Event
    let countdown: Countdown
    let showsWeeks: Bool
    let showsSeconds: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The big number grows with the text size, as text styles do.
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 92

    var body: some View {
        let breakdown = countdown.breakdown(includeWeeks: showsWeeks)

        VStack(spacing: 18) {
            VStack(spacing: 6) {
                EventBadge(symbolName: event.symbolName, color: event.color, size: 56)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                Text(event.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(countdown.targetText)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
                if let eventTime = countdown.eventTimeText {
                    Label(eventTime, systemImage: "globe")
                        .font(.footnote.weight(.medium))
                        .opacity(0.85)
                }
                if countdown.occurrenceNumber > 0 {
                    Text(occurrenceText)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                }
            }

            VStack(spacing: 0) {
                if countdown.isToday {
                    Text("Today")
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                } else {
                    Text(countdown.days, format: .number)
                        .font(.system(size: horizontalSizeClass == .regular ? numberSize * 1.3 : numberSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    Text(CountdownText.dayCaption(countdown))
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                }
            }
            .accessibilityElement(children: .combine)

            BreakdownChips(breakdown: breakdown, showsSeconds: showsSeconds, direction: countdown.direction)

            if let progress = countdown.progress {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.white)
                    Text("\(progress.formatted(.percent.precision(.fractionLength(0)))) of the wait is over")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background { EventBackground(event: event, isMoving: true) }
        .clipShape(.rect(cornerRadius: 32, style: .continuous))
        .shadow(color: event.color.color.opacity(0.35), radius: 24, y: 12)
        .animation(.smooth, value: countdown.target)
    }

    /// "30 years" on the 30th birthday, "6 months" for a monthly event.
    private var occurrenceText: String {
        let unit: TimeUnit = switch event.recurrence {
        case .daily: .day
        case .weekly: .week
        case .monthly: .month
        case .yearly, .never: .year
        }
        let value = countdown.occurrenceNumber
        return "\(value.formatted()) \(CountdownText.unit(unit, value: value))"
    }
}

/// Each unit of a breakdown as a glass tile: "2 years", "3 weeks", "14 seconds".
struct BreakdownChips: View {
    let breakdown: TimeBreakdown
    let showsSeconds: Bool
    let direction: TimeDirection

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let parts = breakdown.parts(includingSeconds: showsSeconds)

        GlassEffectContainer(spacing: 8) {
            // One column per part, up to four, centred — a lone "1 month" sits in the middle.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 64, maximum: 110), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? min(2, max(1, parts.count)) : columnCount(parts.count)), spacing: 8) {
                ForEach(parts) { part in
                    VStack(spacing: 2) {
                        Text(part.value, format: .number)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .fontDesign(.rounded)
                            .contentTransition(.numericText(countsDown: direction == .future))
                        Text(CountdownText.unit(part.unit, value: part.value))
                            .font(.caption2.weight(.medium))
                            .textCase(.uppercase)
                            .opacity(0.85)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .animation(.snappy, value: breakdown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CountdownText.spokenBreakdown(breakdown, includingSeconds: showsSeconds))
    }

    /// Up to four columns; seven parts make rows of four and three.
    private func columnCount(_ parts: Int) -> Int {
        switch parts {
        case ...0: 1
        case 1...4: parts
        case 5, 6: 3
        default: 4
        }
    }
}

/// A rounded card with an optional title, the building block of detail screens.
struct Card<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 24, style: .continuous))
    }
}

/// The span in each unit on its own: 2.5 weeks, 17.4 days, 418 hours.
struct TotalsCard: View {
    let countdown: Countdown
    let tint: Color

    var body: some View {
        let totals = countdown.totals()

        Card(title: "Total Time") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach([TimeUnit.year, .month, .week, .day, .hour, .minute, .second]) { unit in
                    let value = totals.value(of: unit)
                    if unit == .second || value >= 0.01 {
                        GridRow {
                            Text(CountdownText.unit(unit, value: 2).localizedCapitalized)
                                .foregroundStyle(.secondary)
                            Text(CountdownText.total(value))
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(tint)
                                .contentTransition(.numericText())
                                .gridColumnAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

/// The date itself: weekday, week number, day of the year, repetition and reminder.
struct DateDetailsCard: View {
    let event: Event
    let countdown: Countdown

    var body: some View {
        Card(title: "Details") {
            VStack(spacing: 10) {
                LabeledContent("Date", value: countdown.target.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                if !event.isAllDay {
                    LabeledContent("Time", value: countdown.target.formatted(date: .omitted, time: .shortened))
                }
                if let eventTime = countdown.eventTimeText {
                    LabeledContent("Local Time There", value: eventTime)
                }
                if !event.listName.isEmpty {
                    LabeledContent("List", value: event.listName)
                }
                LabeledContent("Week", value: DateMath.weekOfYear(countdown.target).formatted())
                LabeledContent("Day of the Year", value: DateMath.dayOfYear(countdown.target).formatted())
                LabeledContent("Repeats") {
                    Text(RecurrenceText.summary(event.recurrenceRule, start: event.startDate()))
                        .multilineTextAlignment(.trailing)
                }
                if let calendar = event.eventCalendar, event.recurrence == .yearly {
                    LabeledContent(String(localized: calendar.name), value: calendar.formatted(countdown.target))
                }
                if let minutes = event.reminderMinutes {
                    LabeledContent("Reminder") {
                        Text(ReminderOption.title(minutes: minutes, isAllDay: event.isAllDay))
                    }
                }
                if event.recurrence != .never, !event.isYearUnknown {
                    LabeledContent("First Date", value: event.startDate().formatted(date: .long, time: .omitted))
                }
            }
        }
    }
}

/// A "since" counter's streaks: the current one, the longest, and how often it started over.
struct StreakCard: View {
    let event: Event
    let now: Date

    var body: some View {
        let streaks = Streaks(start: event.startDate(), previousStarts: event.resetHistory, now: now)

        Card(title: "Streaks") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Current")
                        .foregroundStyle(.secondary)
                    Text("\(streaks.current.formatted()) \(CountdownText.unit(.day, value: streaks.current))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                GridRow {
                    Text("Longest")
                        .foregroundStyle(.secondary)
                    Text("\(streaks.longest.formatted()) \(CountdownText.unit(.day, value: streaks.longest))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                GridRow {
                    Text("Started Over")
                        .foregroundStyle(.secondary)
                    Text(streaks.resets, format: .number)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}
