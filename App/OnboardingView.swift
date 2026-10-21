import SwiftUI

/// A short welcome: what Timity does, whether to sync through iCloud and share crash reports, birthdays
/// from Contacts, the user's own birthday for Life in Weeks, and a few events to
/// start with.
///
/// Someone updating from Timity 3 is welcomed back instead: what the new Timity brings, in place
/// of What's New, which of their events to bring along, and the same choices, which Timity 3 never
/// asked, without the events to start with.
struct OnboardingView<Importer: View>: View {
    /// Timity 3's events waiting to come over; empty for someone new.
    let timity3Events: [EventSnapshot]
    /// Brings the chosen ones over, telling how many have come so far.
    let moveTimity3Events: (_ events: [EventSnapshot], _ progress: @escaping (Int) async -> Void) async -> Void
    /// Whose holidays the suggestions offer.
    let holidayRegion: HolidayRegion?
    /// Whether Timity has synced through this iCloud account before, from another device.
    let hasSyncedBefore: () async -> Bool
    let importer: () -> Importer
    /// Called once, at the end: nothing the user chooses on the way takes effect before.
    let onFinish: (OnboardingChoices) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var isImporting = false
    @State private var birthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var setsBirthday = false
    @State private var chosen: Set<EventTemplate> = [.newYearsEve, .nextHoliday]
    @State private var syncsWithICloud = true
    /// Off until the user turns it on: sharing reports needs a clear yes.
    @State private var sharesDiagnostics = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Timity 3's events left behind; every one comes along until the user says otherwise.
    @State private var leftBehind: Set<UUID> = []
    /// How the move from Timity 3 is going, once Start Counting has begun it.
    @State private var move: EventMove?

    private var isUpgrade: Bool { !timity3Events.isEmpty }
    private var pages: [OnboardingStep] { OnboardingStep.steps(isUpgrade: isUpgrade) }
    private var lastPage: Int { pages.count - 1 }

    var body: some View {
        NavigationStack {
            if let move {
                EventMoveStatus(move: move, onDone: complete)
            } else {
                pagesView
            }
        }
        // Only Start Counting ends it, so every choice is made before any applies.
        .interactiveDismissDisabled()
        // A sheet on the Mac, small enough that Continue stays inside the window.
        .macSheetSize(width: 560, height: 580)
        .sheet(isPresented: $isImporting) {
            importer()
        }
    }

    private var pagesView: some View {
        OnboardingPages(page: $page, count: pages.count) { index in
            let step = pages[index]
            switch step {
            case .welcome:
                WelcomePage(region: holidayRegion)
            case .welcomeBack:
                WelcomeBackPage(color: step.color)
            case .yourEvents:
                YourEventsPage(color: step.color, events: timity3Events, leftBehind: $leftBehind)
            case .iCloud:
                ICloudPage(color: step.color, hasSyncedBefore: hasSyncedBefore, syncsWithICloud: $syncsWithICloud)
            case .crashReports:
                CrashReportsPage(color: step.color, sharesDiagnostics: $sharesDiagnostics)
            case .importing:
                ImportPage(color: step.color) { isImporting = true }
            case .birthday:
                BirthdayPage(color: step.color, setsBirthday: $setsBirthday, birthday: $birthday)
            case .suggestions:
                SuggestionsPage(color: step.color, region: holidayRegion, chosen: $chosen)
            }
        }
        .background {
            // A soft glow in the page's colour, fading into the background.
            LinearGradient(
                colors: pages[page].color.gradientColors.map { $0.opacity(0.32) } + [.clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.6), value: page)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: verticalSizeClass == .compact ? 8 : 18) {
                PageDots(count: pages.count, current: page)
                Button {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < lastPage ? LocalizedStringKey("common.continue") : LocalizedStringKey("onboarding.startCounting"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.top, verticalSizeClass == .compact ? 4 : 8)
            .padding(.bottom, verticalSizeClass == .compact ? 4 : 12)
        }
    }

    /// Brings the chosen Timity 3 events over first, one by one so it can be followed, then waits
    /// on the result for Start Counting, which applies the rest.
    private func finish() {
        guard isUpgrade else { return complete() }
        let chosen = timity3Events.filter { !leftBehind.contains($0.id) }
        Task {
            guard !chosen.isEmpty else {
                await moveTimity3Events([]) { _ in }
                return complete()
            }
            withAnimation(.smooth) { move = EventMove(events: chosen, moved: 0) }
            // Paced, so a few events can be seen moving, and many still take only a few seconds.
            let pace = Duration.milliseconds(Int(min(450, 3000 / Double(chosen.count))))
            try? await Task.sleep(for: .milliseconds(700))
            await moveTimity3Events(chosen) { moved in
                withAnimation(.snappy) { move?.moved = moved }
                try? await Task.sleep(for: pace)
            }
        }
    }

    private func complete() {
        // Stable IDs, so welcoming a second device before iCloud has brought the
        // events over doesn't add the same suggestions twice.
        // Events to start with only for new users, who were offered them.
        var events = EventTemplate.allCases
            .filter { pages.contains(.suggestions) && chosen.contains($0) }
            .compactMap { template in
                template.draft(region: holidayRegion).map { draft in
                    draft.applied(to: EventSnapshot(id: UUID(stableFrom: "welcome|\(template.rawValue)|\(Int(draft.date.timeIntervalSince1970))")))
                }
            }
        if setsBirthday {
            var draft = EventDraft()
            draft.title = String(localized: "onboarding.myBirthday")
            draft.date = birthday
            draft.isAllDay = true
            draft.recurrence = .yearly
            draft.symbolName = "birthday.cake.fill"
            draft.color = .pink
            let day = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: birthday)
            var event = draft.applied(to: EventSnapshot(id: UUID(stableFrom: "welcome|myBirthday|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)")))
            event.isPinned = true
            events.append(event)
        }
        onFinish(OnboardingChoices(
            events: events,
            birthday: setsBirthday ? birthday : nil,
            syncsWithICloud: syncsWithICloud,
            sharesDiagnostics: sharesDiagnostics
        ))
        dismiss()
    }
}

/// The pages, swiped through on iPhone and iPad; on the Mac, Continue moves between them.
private struct OnboardingPages<Page: View>: View {
    @Binding var page: Int
    let count: Int
    @ViewBuilder let content: (Int) -> Page

    var body: some View {
        #if os(iOS)
        TabView(selection: $page) {
            ForEach(0..<count, id: \.self) { index in
                content(index).tag(index)
            }
        }
        // Its own dots below, so they never sit on top of the suggestions.
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        content(page)
            .id(page)
            .transition(.push(from: .trailing))
        #endif
    }
}

private struct WelcomePage: View {
    let region: HolidayRegion?

    var body: some View {
        OnboardingPage(
            title: "onboarding.welcomeToTimity",
            text: "onboarding.countDownToBirthdaysTrips"
        ) {
            SampleCountdowns(region: region)
        } accessory: {
            EmptyView()
        }
    }
}

/// Welcomes someone back from Timity 3: their events are here, and what the new Timity brings.
private struct WelcomeBackPage: View {
    let color: EventColor

    /// What's new since Timity 3, at a glance; it stands in for What's New.
    private static let highlights: [(symbol: String, color: EventColor, text: LocalizedStringKey)] = [
        ("icloud.fill", .lagoon, "onboarding.upgradeSync"),
        ("square.grid.2x2.fill", .purple, "onboarding.upgradeWidgets"),
        ("applewatch", .graphite, "onboarding.upgradeWatch"),
        ("plus.forwardslash.minus", .orange, "onboarding.upgradeCalculators"),
        ("moon.stars.fill", .indigo, "onboarding.upgradeSky"),
    ]

    var body: some View {
        OnboardingPage(
            title: "onboarding.welcomeToTheNewTimity",
            text: "onboarding.yourEventsAreReady"
        ) {
            // The new Timity's own face: its app icon, as on the Home Screen.
            Image(AppTheme.classic.previewImageName)
                .resizable()
                .frame(width: 104, height: 104)
                .clipShape(.rect(cornerRadius: 104 * 0.225, style: .continuous))
                .shadow(color: color.color.opacity(0.35), radius: 18, y: 8)
        } accessory: {
            OnboardingCard {
                ForEach(Self.highlights, id: \.symbol) { highlight in
                    Label {
                        Text(highlight.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: highlight.symbol)
                            .foregroundStyle(highlight.color.color)
                            // One column for every icon, so the words line up.
                            .frame(width: 28)
                    }
                }
            } footnote: {
                Text("onboarding.aFewChoicesFirst")
            }
        }
    }
}

private struct ICloudPage: View {
    let color: EventColor
    let hasSyncedBefore: () async -> Bool
    @Binding var syncsWithICloud: Bool

    @State private var hasEventsInICloud = false

    var body: some View {
        OnboardingPage(
            title: "common.syncWithICloud",
            text: "onboarding.haveYourEventsOnYour"
        ) {
            OnboardingBadge(symbol: "icloud.fill", color: color)
        } accessory: {
            OnboardingCard {
                OnboardingToggle("common.syncWithICloud", symbol: "icloud.fill", color: color, isOn: $syncsWithICloud)
                if hasEventsInICloud {
                    Divider()
                    // Keeps devices alike: the same choice as on the user's other devices.
                    Label {
                        Text(syncsWithICloud
                            ? LocalizedStringKey("onboarding.yourEventsFromYourOther")
                            : LocalizedStringKey("onboarding.yourOtherDevicesAlreadySync"))
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: syncsWithICloud ? "checkmark.icloud.fill" : "exclamationmark.icloud.fill")
                            .foregroundStyle(syncsWithICloud ? Color.green : Color.orange)
                    }
                    .font(.footnote)
                    // All of it, on as many lines as it needs.
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.symbolEffect(.replace))
                }
            } footnote: {
                Text("onboarding.youCanChangeThisIn")
            }
        }
        .task { hasEventsInICloud = await hasSyncedBefore() }
    }
}

private struct CrashReportsPage: View {
    let color: EventColor
    @Binding var sharesDiagnostics: Bool

    var body: some View {
        OnboardingPage(
            title: "onboarding.helpImproveTimity",
            text: "settings.whenTimityCrashesOrFreezes"
        ) {
            OnboardingBadge(symbol: "stethoscope", color: color)
        } accessory: {
            OnboardingCard {
                OnboardingToggle("settings.shareCrashReports", symbol: "stethoscope", color: color, isOn: $sharesDiagnostics)
            } footnote: {
                Text("onboarding.youCanChangeThisIn")
            }
        }
    }
}

private struct ImportPage: View {
    let color: EventColor
    let startImport: () -> Void

    var body: some View {
        OnboardingPage(
            title: "onboarding.neverMissAMoment",
            text: "onboarding.bringInBirthdaysAndAnniversaries"
        ) {
            OnboardingBadge(symbol: "person.2.fill", color: color)
        } accessory: {
            Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down", action: startImport)
                .buttonStyle(.glass)
                .controlSize(.large)
        }
    }
}

private struct BirthdayPage: View {
    let color: EventColor
    @Binding var setsBirthday: Bool
    @Binding var birthday: Date

    var body: some View {
        OnboardingPage(
            title: "onboarding.yourBirthday",
            text: "onboarding.timityCountsDownToIt"
        ) {
            OnboardingBadge(symbol: "birthday.cake.fill", color: color)
        } accessory: {
            OnboardingCard {
                OnboardingToggle("onboarding.addMyBirthday", symbol: "birthday.cake.fill", color: color, isOn: $setsBirthday.animation())
                if setsBirthday {
                    Divider()
                    DateRow(title: "onboarding.born", date: $birthday, includesTime: false, range: Date.distantPast...Date.now, showsReset: false)
                }
            }
        }
    }
}

private struct SuggestionsPage: View {
    let color: EventColor
    let region: HolidayRegion?
    @Binding var chosen: Set<EventTemplate>

    var body: some View {
        OnboardingPage(title: "onboarding.startWithAFewMoments") {
            OnboardingBadge(symbol: "sparkles", color: color)
        } accessory: {
            VStack(spacing: 10) {
                ForEach(EventTemplate.allCases) { template in
                    if let draft = template.draft(region: region), template != .vacation {
                        ChoiceRow(isChosen: chosen.contains(template)) {
                            if chosen.contains(template) { chosen.remove(template) } else { chosen.insert(template) }
                        } label: {
                            TemplateRow(template: template, title: draft.title)
                        }
                    }
                }
            }
            .animation(.snappy, value: chosen)
            .sensoryFeedback(.selection, trigger: chosen)
        }
    }
}

/// Something to choose in the welcome, ringed in the tint when chosen.
private struct ChoiceRow<Label: View>: View {
    let isChosen: Bool
    let toggle: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: toggle) {
            HStack {
                label
                Spacer()
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(.background.secondary, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// Which of Timity 3's events to bring along, all of them to begin with.
private struct YourEventsPage: View {
    let color: EventColor
    let events: [EventSnapshot]
    @Binding var leftBehind: Set<UUID>

    var body: some View {
        OnboardingPage(
            title: "onboarding.yourEvents",
            text: "onboarding.chooseWhichEventsToBring"
        ) {
            OnboardingBadge(symbol: "tray.and.arrow.down.fill", color: color)
        } accessory: {
            VStack(spacing: 10) {
                HStack {
                    Text("onboarding.selectedOf \(events.count - leftBehind.count) \(events.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    Spacer()
                    Button(leftBehind.isEmpty ? "common.deselectAll" : "common.selectAll") {
                        leftBehind = leftBehind.isEmpty ? Set(events.map(\.id)) : []
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 4)
                ForEach(events) { event in
                    ChoiceRow(isChosen: !leftBehind.contains(event.id)) {
                        if leftBehind.contains(event.id) { leftBehind.remove(event.id) } else { leftBehind.insert(event.id) }
                    } label: {
                        Timity3EventLabel(event: event)
                    }
                }
            }
            .animation(.snappy, value: leftBehind)
            .sensoryFeedback(.selection, trigger: leftBehind)
        }
    }
}

/// A Timity 3 event as the list shows it: its symbol in its colour, its name and date.
private struct Timity3EventLabel: View {
    let event: EventSnapshot

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.symbolName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(event.color.gradient, in: .rect(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(event.date, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// How far the move from Timity 3 has got: which of the chosen events have come over.
struct EventMove {
    let events: [EventSnapshot]
    var moved: Int

    var total: Int { events.count }
    var isDone: Bool { moved >= total }
    var fraction: Double { total == 0 ? 1 : Double(moved) / Double(total) }
}

/// The move from Timity 3, in place of the pages and in Timity's own look: the app icon's ring
/// filling as the events come over, each one landing on a stack of countdown cards like those the
/// welcome shows new users, and Start Counting once all have.
private struct EventMoveStatus: View {
    let move: EventMove
    let onDone: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // With the iPhone on its side, the ring beside the cards, as the screen is wide but short.
        let layout = verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(spacing: 48))
            : AnyLayout(VStackLayout(spacing: 44))
        layout {
            VStack(spacing: 24) {
                MoveRing(move: move)
                VStack(spacing: 8) {
                    Text(move.isDone ? "onboarding.allSet" : "onboarding.movingYourEvents")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                        .id(move.isDone)
                        .transition(.blurReplace)
                    Text("onboarding.eventsMovedOf \(move.moved) \(move.total)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
            }
            ArrivalStack(events: Array(move.events.prefix(move.moved)))
        }
        .frame(maxWidth: verticalSizeClass == .compact ? 820 : 480)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // The icon's warm light behind the ring, in one hue so it fades without a band.
            ZStack {
                LinearGradient(colors: [MoveRing.amber.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
                RadialGradient(
                    colors: [MoveRing.orange.opacity(0.26), MoveRing.orange.opacity(0.08), .clear],
                    center: verticalSizeClass == .compact ? UnitPoint(x: 0.28, y: 0.45) : UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 0,
                    endRadius: 380
                )
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            if move.isDone {
                Button(action: onDone) {
                    Text("onboarding.startCounting")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, verticalSizeClass == .compact ? 4 : 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: move.isDone)
        .sensoryFeedback(.success, trigger: move.isDone) { _, isDone in isDone }
    }
}

/// The events that have come over as a fanned stack of countdown cards: each new one slides in
/// at the front while the earlier ones tilt and step back; the three latest show.
private struct ArrivalStack: View {
    /// The events that have come over, in the order they came.
    let events: [EventSnapshot]

    private static let visible = 3

    var body: some View {
        let shown = Array(events.suffix(Self.visible).reversed())
        ZStack {
            ForEach(Array(shown.enumerated()), id: \.element.id) { depth, event in
                ArrivedEventCard(event: event, isInFront: depth == 0)
                    .scaleEffect(1 - CGFloat(depth) * 0.06)
                    .offset(y: CGFloat(depth) * -26)
                    .rotationEffect(.degrees([0, -2.5, 2][depth]))
                    .opacity(1 - Double(depth) * 0.25)
                    .zIndex(Double(Self.visible - depth))
                    .transition(.asymmetric(
                        insertion: .offset(y: 70).combined(with: .scale(scale: 0.9)).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: 360)
        // Room for the stack from the start, so nothing moves as the cards arrive.
        .frame(height: 140, alignment: .bottom)
        .animation(.spring(duration: 0.55, bounce: 0.3), value: events.count)
    }
}

/// The app icon's ring, filling amber to orange as the events come over, its white dot riding the
/// end of the arc, and how many have come in the middle, in the countdowns' own digits.
private struct MoveRing: View {
    let move: EventMove

    /// The app icon's ring runs from this warm amber…
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.29)
    /// …to this orange.
    static let orange = Color(red: 1.0, green: 0.35, blue: 0.12)

    private let size: CGFloat = 168
    private let lineWidth: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(Self.amber.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: move.fraction)
                .stroke(
                    AngularGradient(
                        colors: [Self.amber, Self.orange],
                        center: .center,
                        startAngle: .zero,
                        endAngle: .degrees(360 * max(move.fraction, 0.05))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            // The icon's dot: white, orange at its heart, at the moment the arc has reached.
            ZStack {
                Circle().fill(.white)
                Circle().fill(Self.orange).padding(lineWidth * 0.5)
            }
            .frame(width: lineWidth * 1.9, height: lineWidth * 1.9)
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            .offset(y: -lineWidth * 0.95)
            .frame(width: size, height: size, alignment: .top)
            .rotationEffect(.degrees(360 * move.fraction))
            Text(verbatim: move.moved.localizedNumber)
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// An event that has come over, as the countdown card it now is; behind the front one, only
/// its edge shows, as in a stack.
private struct ArrivedEventCard: View {
    let event: EventSnapshot
    let isInFront: Bool

    var body: some View {
        HStack(spacing: 12) {
            EventThumbnail(event: event, size: 40)
            Text(event.title)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 8)
            DayCount(countdown: event.countdown(), color: event.color)
        }
        .opacity(isInFront ? 1 : 0)
        .animation(.smooth, value: isInFront)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Solid, as in the list, so a card stacked in front hides those behind it.
        .background(.background, in: .rect(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }
}

/// The welcome's pages, in order, each in its own colour.
enum OnboardingStep: Equatable {
    case welcome, welcomeBack, yourEvents, iCloud, crashReports, importing, birthday, suggestions

    /// A new user's pages, or the welcome back for someone who used Timity 3: what's new
    /// instead of what Timity is, which of their events to bring along, the same choices, and no
    /// events to start with, as they have theirs.
    static func steps(isUpgrade: Bool) -> [OnboardingStep] {
        isUpgrade
            ? [.welcomeBack, .yourEvents, .iCloud, .crashReports, .importing, .birthday]
            : [.welcome, .iCloud, .crashReports, .importing, .birthday, .suggestions]
    }

    /// The colour of the page's badge and the glow behind it.
    var color: EventColor {
        switch self {
        case .welcome, .welcomeBack: .ember
        case .iCloud: .lagoon
        case .crashReports: .aurora
        case .yourEvents, .importing: .nightfall
        case .birthday: .blossom
        case .suggestions: .sunrise
        }
    }
}

/// What the user chose in the welcome, applied all at once when it ends.
struct OnboardingChoices {
    var events: [EventSnapshot]
    var birthday: Date?
    var syncsWithICloud: Bool
    var sharesDiagnostics: Bool
}

/// A page of the welcome: a picture, a title and a few words, and what to do,
/// in the middle of the screen when it fits and scrolling when it doesn't.
private struct OnboardingPage<Hero: View, Accessory: View>: View {
    let title: LocalizedStringKey
    var text: LocalizedStringKey?
    @ViewBuilder var hero: Hero
    @ViewBuilder var accessory: Accessory

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // With the iPhone on its side, the picture beside the words, as the screen is wide
        // but short: the picture stays in place while a long page scrolls on the right.
        if verticalSizeClass == .compact {
            HStack(spacing: 40) {
                hero
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                CenteredScrollView(maxWidth: 440) {
                    VStack(spacing: 20) {
                        OnboardingWords(title: title, text: text)
                        accessory
                    }
                    .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        } else {
            CenteredScrollView(maxWidth: 560) {
                VStack(spacing: 28) {
                    hero
                        .accessibilityHidden(true)
                    OnboardingWords(title: title, text: text)
                    accessory
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
        }
    }
}

/// Scrolls when the content is taller than the room, centred in it when it isn't.
private struct CenteredScrollView<Content: View>: View {
    let maxWidth: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: maxWidth)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// A page's title and its few words.
private struct OnboardingWords: View {
    let title: LocalizedStringKey
    let text: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                // Wraps rather than cutting a long title short, as "Never Miss a Mom…".
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let text {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// The page's symbol on a rounded square in its colour, like an app icon.
private struct OnboardingBadge: View {
    let symbol: String
    let color: EventColor

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(color.gradient)
            .frame(width: 104, height: 104)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: color.color.opacity(0.45), radius: 24, y: 12)
    }
}

/// Settings on the page, grouped on glass, with an optional note below.
private struct OnboardingCard<Content: View, Footnote: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var footnote: Footnote

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 26, style: .continuous))
            footnote
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 400)
    }
}

extension OnboardingCard where Footnote == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
    }
}

/// A switch in a card, with its own small coloured icon, as in Settings.
private struct OnboardingToggle: View {
    let title: LocalizedStringKey
    let symbol: String
    let color: EventColor
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, symbol: String, color: EventColor, isOn: Binding<Bool>) {
        self.title = title
        self.symbol = symbol
        self.color = color
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                EventBadge(symbolName: symbol, color: color, size: 32)
                Text(title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A few real countdowns, fanned out, to show at a glance what Timity is for.
private struct SampleCountdowns: View {
    let region: HolidayRegion?

    var body: some View {
        let samples: [(EventTemplate, EventSnapshot)] = [EventTemplate.weekend, .christmas, .newYearsEve].compactMap { template in
            template.draft(region: region).map { (template, $0.applied()) }
        }
        VStack(spacing: -14) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                let (template, event) = sample
                HStack(spacing: 12) {
                    EventBadge(symbolName: template.symbolName, color: template.color, size: 40)
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    DayCount(countdown: event.countdown(), color: template.color)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: 300)
                .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
                .rotationEffect(.degrees([-4, 2, -1][index % 3]))
                .offset(x: [-14, 16, -6][index % 3])
                .zIndex(Double(index))
            }
        }
        .padding(.vertical, 8)
    }
}

/// Where in the welcome the user is: the current page as a longer dash.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        // The pages are swiped or stepped through with Continue; VoiceOver reads the page itself.
        .accessibilityHidden(true)
    }
}
