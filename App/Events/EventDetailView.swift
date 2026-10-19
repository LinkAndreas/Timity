import SwiftUI
import TipKit

/// One event: a live countdown over its colour or photo, then the span in every
/// unit and the details of the date.
struct EventDetailView: View {
    let event: EventSnapshot
    let liveActivities: any LiveActivityControlling
    let onEdit: () -> Void
    /// Saves the event changed here, e.g. pinned or ticked off.
    let onSave: (EventSnapshot) -> Void
    /// Closes the page and deletes the event.
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false
    @State private var isConfirmingStartOver = false
    @State private var isAddingToCalendar = false
    @State private var shareImage: Image?
    @State private var isLiveActivityRunning = false

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The page's width, for the countdown beside the cards where both fit.
    @State private var width: CGFloat = 0

    /// Wide enough for the countdown and the cards side by side, as a large Mac or iPad window.
    private static let sideBySideWidth: CGFloat = 900

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = event.countdown(at: context.date)

            // With the iPhone on its side or in a wide window, the countdown beside the rest,
            // each scrolling on its own, so the countdown stays in view while the cards scroll by.
            if verticalSizeClass == .compact || width >= Self.sideBySideWidth {
                HStack(alignment: .top, spacing: 16) {
                    ScrollView {
                        VStack(spacing: 16) {
                            hero(countdown: countdown, now: context.date)
                        }
                        .padding(.vertical)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    ScrollView {
                        VStack(spacing: 16) {
                            cards(countdown: countdown, now: context.date)
                        }
                        .padding(.vertical)
                    }
                }
                .padding(.horizontal)
                // Two columns of a readable width, not stretched across a very wide window.
                .frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        hero(countdown: countdown, now: context.date)
                        cards(countdown: countdown, now: context.date)
                    }
                    .padding()
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
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
        .inlineNavigationTitle()
        // With the iPhone on its side, the page has the screen's whole height; Back returns to the tabs.
        .tabBarHidden(verticalSizeClass == .compact)
        .task { await EventMenuTip.eventOpened.donate() }
        .toolbar {
            #if os(macOS)
            // Edit and one menu for the rest, side by side at the window's trailing edge,
            // as on iPhone; apart, the menu sat on its own in the middle of the toolbar.
            // (On the Mac, the primary action's place is the leading edge.)
            ToolbarItemGroup(placement: .automatic) {
                Button("common.edit", action: onEdit)
                Menu("events.more", systemImage: "ellipsis") {
                    moreActions
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("common.edit", action: onEdit)
                    .keyboardShortcut("e")
            }
            // A menu of its own, not the toolbar's overflow: sharing opens from the menu's
            // button, and from the overflow's items, gone once it closes, the app crashed.
            ToolbarItem(placement: .primaryAction) {
                Menu("events.more", systemImage: "ellipsis") {
                    moreActions
                }
            }
            #endif
        }
        .sensoryFeedback(.impact(weight: .light), trigger: event.isPinned)
        // The share picture changes once a day, with the day count.
        .task(id: "\(event.countdown().days)-\(event.modifiedAt.timeIntervalSince1970)") {
            shareImage = ShareCard.image(for: event, countdown: event.countdown())
            isLiveActivityRunning = liveActivities.isRunning(for: event.id)
        }
        .sheet(isPresented: $isAddingToCalendar) {
            AddToCalendarSheet(event: event)
                .ignoresSafeArea()
        }
        // Standard alerts in the middle, not bubbles at the menu's edge.
        .alert("eventDetail.startOver", isPresented: $isConfirmingStartOver) {
            Button("editor.cancel", role: .cancel) {}
            Button("common.startOver") {
                var restarted = event
                restarted.startOver()
                withAnimation { onSave(restarted) }
            }
        } message: {
            Text("eventDetail.theCountStartsAgainFrom")
        }
        .alert("common.deleteEvent", isPresented: $isConfirmingDelete) {
            Button("editor.cancel", role: .cancel) {}
            Button("common.delete", role: .destructive, action: onDelete)
        } message: {
            Text("common.theEventIsDeletedOn")
        }
    }

    /// Pinning, sharing, the calendar, starting over, archiving and deleting.
    @ViewBuilder
    private var moreActions: some View {
        Button(event.isPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
            onSave(event.togglingPin())
        }
        if let shareImage {
            ShareLink(item: shareImage, preview: SharePreview(event.title, image: shareImage)) {
                Label("eventDetail.shareAsImage", systemImage: "photo")
            }
        }
        ShareLink(item: EventShareText.text(for: event)) {
            Label("eventDetail.shareAsText", systemImage: "text.quote")
        }
        ShareLink(item: EventFileTransfer(event: event), preview: SharePreview(event.title)) {
            Label("common.sendACopy", systemImage: "paperplane")
        }
        Button("eventDetail.addToCalendar", systemImage: "calendar.badge.plus") {
            isAddingToCalendar = true
        }
        if event.recurrence == .never, event.startDate() < .now {
            Button("common.startOver", systemImage: "arrow.counterclockwise") {
                isConfirmingStartOver = true
            }
        }
        Button(event.isArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
               systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
            onSave(event.togglingArchive())
        }
        Button("common.delete", systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
        }
    }
}

extension EventDetailView {
    /// The countdown, and starting it on the Lock Screen.
    @ViewBuilder
    fileprivate func hero(countdown: Countdown, now: Date) -> some View {
        CountdownHero(event: event, countdown: countdown)
        if liveActivities.canStart(for: countdown, now: now) || isLiveActivityRunning {
            liveActivityButton(countdown: countdown)
        }
    }

    /// The totals, milestones, dates and notes below the countdown.
    @ViewBuilder
    fileprivate func cards(countdown: Countdown, now: Date) -> some View {
        TipView(EventMenuTip())
            // Like the cards below it, as the page isn't grey like the list.
            .tipBackground(.background.secondary)
        let span = event.span(at: now)
        // The next time, where that isn't the event's own date — which the span shows.
        if span?.date != countdown.target {
            EventSpanCard(event: event, countdown: countdown, tint: event.color.color)
        }
        if let span {
            EventSpanCard(event: event, span: span, tint: event.color.color)
        }
        if !event.resetHistory.isEmpty {
            StreakCard(event: event, now: now)
        }
        if !event.isYearUnknown {
            MilestonesCard(event: event, now: now, tint: event.color.color)
        }
        DateDetailsCard(event: event, countdown: countdown)
        if !event.notes.isEmpty {
            Card(title: "common.notes") {
                Text(event.notes)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    /// Puts the last hours on the Lock Screen and in the Dynamic Island.
    fileprivate func liveActivityButton(countdown: Countdown) -> some View {
        Button {
            if isLiveActivityRunning {
                Task { await liveActivities.end(for: event.id) }
                withAnimation { isLiveActivityRunning = false }
            } else {
                liveActivities.start(for: event, target: countdown.target)
                // Only what really started: the system can turn a request down.
                withAnimation { isLiveActivityRunning = liveActivities.isRunning(for: event.id) }
            }
        } label: {
            Label(
                isLiveActivityRunning ? LocalizedStringKey("eventDetail.removeFromLockScreen") : LocalizedStringKey("eventDetail.showOnLockScreen"),
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
    let event: EventSnapshot
    let countdown: Countdown

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Short with the iPhone on its side: everything a little smaller, so the countdown fits the screen's height.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The big number grows with the text size, as text styles do.
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 92

    private var isShort: Bool { verticalSizeClass == .compact }

    var body: some View {
        if event.imageData != nil {
            posterHero
        } else {
            colorHero
        }
    }

    // MARK: With a photo

    /// The photo on top with only the name on it, and the countdown below on the
    /// event's colour: nothing covers the photo, and the numbers read the same on any
    /// photo, bright or dark, busy or calm.
    private var posterHero: some View {
        VStack(spacing: 0) {
            EventBackground(event: event, isMoving: true)
                .frame(height: isShort ? 170 : horizontalSizeClass == .regular ? 380 : 300)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    posterTitle
                        .padding(20)
                }
            posterCountdown
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(event.color.gradient)
        }
        .foregroundStyle(.white)
        .clipShape(.rect(cornerRadius: 32, style: .continuous))
        .shadow(color: event.color.color.opacity(0.35), radius: 24, y: 12)
        .animation(.smooth, value: countdown.target)
    }

    /// The badge, name and date at the photo's bottom left, on its shade.
    private var posterTitle: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                EventBadge(symbolName: event.symbolName, color: event.color, size: 36)
                Text(event.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
            }
            Text(verbatim: countdown.occurrenceNumber > 0 ? "\(countdown.targetText) · \(occurrenceText)" : countdown.targetText)
                .font(.subheadline.weight(.medium))
                .opacity(0.9)
            if let eventTime = countdown.eventTimeText {
                Label(eventTime, systemImage: "globe")
                    .font(.footnote.weight(.medium))
                    .opacity(0.9)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        .accessibilityElement(children: .combine)
    }

    /// The days, the rest of the span in one line, and how much of the wait is over.
    private var posterCountdown: some View {
        let breakdown = countdown.breakdown(includeWeeks: true)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if countdown.isToday {
                    Text("common.today")
                        .scaledFont(size: 56, weight: .heavy, design: .rounded)
                } else {
                    Text(countdown.days, format: .number)
                        .scaledFont(size: 64, weight: .heavy, design: .rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    Text(CountdownText.dayCaption(countdown))
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .combine)

            let line = CountdownText.compactBreakdown(breakdown, includingSeconds: true)
            if !line.isEmpty {
                Text(verbatim: line)
                    .font(.headline)
                    .monospacedDigit()
                    .opacity(0.9)
                    .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    .accessibilityLabel(CountdownText.spokenBreakdown(breakdown, includingSeconds: true))
            }

            if let progress = countdown.progress {
                if progress >= 1, countdown.direction != .future {
                    Label("progress.theWaitIsOver", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                } else {
                    HStack(spacing: 10) {
                        EventProgressBar(progress: progress, fill: .white, track: .white.opacity(0.3), height: 8)
                        Text(EventProgressText.percent(progress))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .padding(.top, 4)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("common.ofTheWaitIsOver \(EventProgressText.percent(progress))"))
                    .accessibilityValue(countdown.progressDays().map { Text("progress.ofDays \($0.gone) \($0.total)") } ?? Text(verbatim: ""))
                }
            }
        }
    }

    // MARK: Without a photo

    /// The event's colour behind the name, the days and each unit on glass.
    @ViewBuilder
    private var colorHero: some View {
        let breakdown = countdown.breakdown(includeWeeks: true)

        VStack(spacing: isShort ? 12 : 18) {
            // Straight on the photo, which the background shades behind it, with a soft
            // shadow so the words hold on bright spots too — on the words alone: on the
            // glass it would ring the badge and the age in a dark smudge.
            VStack(spacing: 6) {
                heroBadge(size: isShort ? 40 : 56)
                Text(event.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                Text(countdown.targetText)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                if let eventTime = countdown.eventTimeText {
                    Label(eventTime, systemImage: "globe")
                        .font(.footnote.weight(.medium))
                        .opacity(0.85)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                }
                if countdown.occurrenceNumber > 0 {
                    // Clear glass like the badge and the units, the shadow on its words only.
                    Text(occurrenceText)
                        .font(.footnote.weight(.semibold))
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .glassEffect(.clear, in: .capsule)
                }
            }
            .frame(maxWidth: 480)

            VStack(spacing: 0) {
                if countdown.isToday {
                    Text("common.today")
                        .scaledFont(size: 72, weight: .heavy, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(countdown.days, format: .number)
                        .font(.system(size: horizontalSizeClass == .regular ? numberSize * 1.3 : isShort ? numberSize * 0.75 : numberSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: countdown.direction == .future))
                    Text(CountdownText.dayCaption(countdown))
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 10, y: 2)
            .accessibilityElement(children: .combine)

            BreakdownChips(breakdown: breakdown, showsSeconds: true, direction: countdown.direction)

            if let progress = countdown.progress {
                HeroEventProgress(countdown: countdown, progress: progress)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, isShort ? 18 : 28)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background { EventBackground(event: event, isMoving: true) }
        .clipShape(.rect(cornerRadius: 32, style: .continuous))
        .shadow(color: event.color.color.opacity(0.35), radius: 24, y: 12)
        .animation(.smooth, value: countdown.target)
    }

    /// The symbol on clear glass, like the units below: a badge in the event's own
    /// colour would vanish into the same colour behind it, and its shadow smudged it.
    private func heroBadge(size: CGFloat) -> some View {
        Image(systemName: event.symbolName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            .frame(width: size, height: size)
            .glassEffect(.clear, in: .rect(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
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
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    // Clear glass, so the photo shows through; the shade behind keeps it readable.
                    .glassEffect(.clear, in: .rect(cornerRadius: 18, style: .continuous))
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
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: 24, style: .continuous))
    }
}

/// A span in each unit on its own, one unit to a row.
struct TotalsGrid: View {
    let totals: TimeTotals
    let tint: Color

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach([TimeUnit.year, .month, .week, .day, .hour, .minute, .second]) { unit in
                let value = totals.value(of: unit)
                if unit == .second || value >= 0.01 {
                    UnitRow(unit: unit, value: Text(CountdownText.total(value)), tint: tint)
                }
            }
        }
    }
}

/// A unit's name on the left and its value on the right, in the event's colour.
private struct UnitRow: View {
    let unit: TimeUnit
    let value: Text
    let tint: Color

    var body: some View {
        GridRow {
            Text(CountdownText.unit(unit, value: 2).localizedCapitalized)
                .foregroundStyle(.secondary)
            value
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .gridColumnAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The time between now and a date of the event, the same for every kind of event: a
/// birthday's exact age since its first time, how long until or since a one-off event, or
/// until a repeating event's next time — the date with its weekday and time, the span in
/// years down to seconds, and in each unit on its own.
struct EventSpanCard: View {
    let title: LocalizedStringKey
    let dateTitle: LocalizedStringKey
    let date: Date
    let showsTime: Bool
    let breakdown: TimeBreakdown
    let totals: TimeTotals
    let tint: Color

    var body: some View {
        Card(title: title) {
            VStack(spacing: 10) {
                LabeledContent(dateTitle, value: date.formatted(.fullDate()))
                if showsTime {
                    LabeledContent("common.time", value: date.formatted(date: .omitted, time: .shortened))
                }
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach([TimeUnit.year, .month, .day, .hour, .minute, .second]) { unit in
                    UnitRow(unit: unit, value: Text(breakdown.value(of: unit), format: .number), tint: tint)
                }
            }
            Divider()
            Text("eventDetail.totalTime")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            TotalsGrid(totals: totals, tint: tint)
        }
    }
}

extension EventSpanCard {
    /// The event's own date: its first time, or a one-off event's only one.
    init(event: EventSnapshot, span: EventSpan, tint: Color) {
        let title: LocalizedStringKey = switch (span.isFirstOccurrence, span.isPast) {
        case (true, true): "eventDetail.sinceTheStart"
        case (false, true): "eventDetail.sinceTheDate"
        case (_, false): "eventDetail.untilTheDate"
        }
        self.init(
            title: title,
            dateTitle: span.isFirstOccurrence ? "eventDetail.firstDate" : "common.date",
            date: span.date,
            showsTime: !event.isAllDay,
            breakdown: span.breakdown,
            totals: span.totals,
            tint: tint
        )
    }

    /// The occurrence the countdown counts towards, a repeating event's next time.
    init(event: EventSnapshot, countdown: Countdown, tint: Color) {
        self.init(
            title: countdown.direction == .past ? "eventDetail.sinceTheDate" : "eventDetail.untilTheNextTime",
            dateTitle: "eventDetail.nextDate",
            date: countdown.target,
            showsTime: !event.isAllDay,
            breakdown: countdown.breakdown(includeWeeks: false),
            totals: countdown.totals(),
            tint: tint
        )
    }
}

/// The date itself: weekday, week number, day of the year, repetition and reminder.
struct DateDetailsCard: View {
    let event: EventSnapshot
    let countdown: Countdown

    var body: some View {
        // The date and time show with the span when it's the event's own date.
        let showsDate = event.span(at: countdown.now)?.date != countdown.target
        Card(title: "common.details") {
            VStack(spacing: 10) {
                if showsDate {
                    LabeledContent("common.date", value: countdown.target.formatted(.fullDate()))
                    if !event.isAllDay {
                        LabeledContent("common.time", value: countdown.target.formatted(date: .omitted, time: .shortened))
                    }
                }
                if let eventTime = countdown.eventTimeText {
                    LabeledContent("eventDetail.localTimeThere", value: eventTime)
                }
                if !event.listName.isEmpty {
                    LabeledContent("common.list", value: event.listName)
                }
                LabeledContent("common.week2", value: DateMath.weekOfYear(countdown.target).formatted())
                LabeledContent("common.dayOfTheYear", value: DateMath.dayOfYear(countdown.target).formatted())
                LabeledContent("common.repeats") {
                    Text(RecurrenceText.summary(event.rule, start: event.startDate()))
                        .multilineTextAlignment(.trailing)
                }
                if let calendar = event.eventCalendar, event.recurrence == .yearly {
                    LabeledContent(String(localized: calendar.name), value: calendar.formatted(countdown.target))
                }
                if let minutes = event.reminderMinutes {
                    LabeledContent("common.reminder") {
                        Text(ReminderOption.title(minutes: minutes, isAllDay: event.isAllDay))
                    }
                }
            }
        }
    }
}

/// A "since" counter's streaks: the current one, the longest, and how often it started over.
struct StreakCard: View {
    let event: EventSnapshot
    let now: Date

    var body: some View {
        let streaks = Streaks(start: event.startDate(), previousStarts: event.resetHistory, now: now)

        Card(title: "eventDetail.streaks") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("eventDetail.current")
                        .foregroundStyle(.secondary)
                    Text("\(streaks.current.formatted()) \(CountdownText.unit(.day, value: streaks.current))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                GridRow {
                    Text("eventDetail.longest")
                        .foregroundStyle(.secondary)
                    Text("\(streaks.longest.formatted()) \(CountdownText.unit(.day, value: streaks.longest))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                GridRow {
                    Text("eventDetail.startedOver")
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
