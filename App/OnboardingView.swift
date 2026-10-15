import SwiftUI

/// A short welcome: what Timity does, whether to sync through iCloud and share crash reports, birthdays
/// from Contacts, the user's own birthday for Life in Weeks, and a few events to
/// start with.
struct OnboardingView<Importer: View>: View {
    /// Whose holidays the suggestions offer.
    let holidayRegion: HolidayRegion?
    /// Whether Timity has synced through this iCloud account before, from another device.
    let hasSyncedBefore: () async -> Bool
    let importer: () -> Importer
    /// Called once, at the end: nothing the user chooses on the way takes effect before.
    let onFinish: (OnboardingChoices) -> Void

    private static var lastPage: Int { 5 }

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var isImporting = false
    @State private var birthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var setsBirthday = false
    @State private var chosen: Set<EventTemplate> = [.newYearsEve, .nextHoliday]
    @State private var hasEventsInICloud = false
    @State private var syncsWithICloud = true
    /// Starts on: the page offers sharing crash reports with the toggle already on.
    @State private var sharesDiagnostics = true

    /// Each page's own colour, for its badge and the glow behind it.
    private static var pageColors: [EventColor] { [.ember, .lagoon, .aurora, .nightfall, .blossom, .sunrise] }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                welcome.tag(0)
                iCloudPage.tag(1)
                crashReportsPage.tag(2)
                importPage.tag(3)
                birthdayPage.tag(4)
                suggestions.tag(Self.lastPage)
            }
            // Its own dots below, so they never sit on top of the suggestions.
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background {
                // A soft glow in the page's colour, fading into the background.
                LinearGradient(
                    colors: Self.pageColors[page].gradientColors.map { $0.opacity(0.32) } + [.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(.smooth(duration: 0.6), value: page)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 18) {
                    PageDots(count: Self.lastPage + 1, current: page)
                    Button {
                        if page < Self.lastPage {
                            withAnimation { page += 1 }
                        } else {
                            finish()
                        }
                    } label: {
                        Text(page < Self.lastPage ? LocalizedStringKey("common.continue") : LocalizedStringKey("onboarding.startCounting"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        // Only Start Counting ends it, so every choice is made before any applies.
        .interactiveDismissDisabled()
        .sheet(isPresented: $isImporting) {
            importer()
        }
    }

    private var welcome: some View {
        OnboardingPage(
            title: "onboarding.welcomeToTimity",
            text: "onboarding.countDownToBirthdaysTrips"
        ) {
            SampleCountdowns(region: holidayRegion)
        } accessory: {
            EmptyView()
        }
    }

    private var iCloudPage: some View {
        OnboardingPage(
            title: "common.syncWithICloud",
            text: "onboarding.haveYourEventsOnYour"
        ) {
            OnboardingBadge(symbol: "icloud.fill", color: Self.pageColors[1])
        } accessory: {
            OnboardingCard {
                Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
                if hasEventsInICloud {
                    Divider()
                    // Keeps devices alike: the same choice as on the user's other devices.
                    Label(
                        syncsWithICloud
                            ? LocalizedStringKey("onboarding.yourEventsFromYourOther")
                            : LocalizedStringKey("onboarding.yourOtherDevicesAlreadySync"),
                        systemImage: syncsWithICloud ? "checkmark.icloud" : "exclamationmark.icloud"
                    )
                    .font(.footnote)
                    .foregroundStyle(syncsWithICloud ? Color.secondary : Color.orange)
                }
            } footnote: {
                Text("onboarding.youCanChangeThisIn")
            }
        }
        .task { hasEventsInICloud = await hasSyncedBefore() }
    }

    private var crashReportsPage: some View {
        OnboardingPage(
            title: "onboarding.helpImproveTimity",
            text: "settings.whenTimityCrashesOrFreezes"
        ) {
            OnboardingBadge(symbol: "stethoscope", color: Self.pageColors[2])
        } accessory: {
            OnboardingCard {
                Toggle("settings.shareCrashReports", isOn: $sharesDiagnostics)
            } footnote: {
                Text("onboarding.youCanChangeThisIn")
            }
        }
    }

    private var importPage: some View {
        OnboardingPage(
            title: "onboarding.neverMissAMoment",
            text: "onboarding.bringInBirthdaysAndAnniversaries"
        ) {
            OnboardingBadge(symbol: "person.2.fill", color: Self.pageColors[3])
        } accessory: {
            Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    private var birthdayPage: some View {
        OnboardingPage(
            title: "onboarding.yourBirthday",
            text: "onboarding.timityCountsDownToIt"
        ) {
            OnboardingBadge(symbol: "birthday.cake.fill", color: Self.pageColors[4])
        } accessory: {
            OnboardingCard {
                Toggle("onboarding.addMyBirthday", isOn: $setsBirthday.animation())
                if setsBirthday {
                    Divider()
                    DatePicker("onboarding.born", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                }
            }
        }
    }

    private var suggestions: some View {
        OnboardingPage(title: "onboarding.startWithAFewMoments") {
            OnboardingBadge(symbol: "sparkles", color: Self.pageColors[5])
        } accessory: {
            VStack(spacing: 10) {
                ForEach(EventTemplate.allCases) { template in
                    if let draft = template.draft(region: holidayRegion), template != .vacation {
                        let isChosen = chosen.contains(template)
                        Button {
                            if isChosen { chosen.remove(template) } else { chosen.insert(template) }
                        } label: {
                            HStack {
                                TemplateRow(template: template, title: draft.title)
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
            }
            .animation(.snappy, value: chosen)
            .sensoryFeedback(.selection, trigger: chosen)
        }
    }

    private func finish() {
        // Stable IDs, so welcoming a second device before iCloud has brought the
        // events over doesn't add the same suggestions twice.
        var events = EventTemplate.allCases
            .filter(chosen.contains)
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

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    hero
                        .accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        if let text {
                            Text(text)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    accessory
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
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
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
            footnote
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 400)
    }
}

extension OnboardingCard where Footnote == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
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
