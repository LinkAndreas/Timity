import SwiftUI

/// A short welcome: what Timity does, whether to sync through iCloud, birthdays
/// from Contacts, the user's own birthday for Life in Weeks, and a few events to
/// start with.
struct OnboardingView<Importer: View>: View {
    /// Whose holidays the suggestions offer.
    let holidayRegion: HolidayRegion?
    @Binding var syncsWithICloud: Bool
    /// Whether Timity has synced through this iCloud account before, from another device.
    let hasSyncedBefore: () async -> Bool
    let importer: () -> Importer
    /// Called once the welcome is done, with the events to add and the user's birthday if given.
    let onFinish: (_ events: [EventSnapshot], _ birthday: Date?) -> Void

    private static var lastPage: Int { 4 }

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var isImporting = false
    @State private var birthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var setsBirthday = false
    @State private var chosen: Set<EventTemplate> = [.newYearsEve, .nextHoliday]
    @State private var hasEventsInICloud = false

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                welcome.tag(0)
                iCloudPage.tag(1)
                importPage.tag(2)
                birthdayPage.tag(3)
                suggestions.tag(Self.lastPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("onboarding.skip") { finish(addingSuggestions: false) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if page < Self.lastPage {
                        withAnimation { page += 1 }
                    } else {
                        finish(addingSuggestions: true)
                    }
                } label: {
                    Text(page < Self.lastPage ? LocalizedStringKey("common.continue") : LocalizedStringKey("onboarding.startCounting"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $isImporting) {
            importer()
        }
    }

    private var welcome: some View {
        OnboardingPage(
            symbol: "hourglass",
            title: "onboarding.welcomeToTimity",
            text: "onboarding.countDownToBirthdaysTrips"
        )
    }

    private var iCloudPage: some View {
        OnboardingPage(
            symbol: "icloud.fill",
            title: "common.syncWithICloud",
            text: "onboarding.haveYourEventsOnYour"
        ) {
            Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
                .frame(maxWidth: 320)
            if hasEventsInICloud {
                // Keeps devices alike: the same choice as on the user's other devices.
                Label(
                    syncsWithICloud
                        ? LocalizedStringKey("onboarding.yourEventsFromYourOther")
                        : LocalizedStringKey("onboarding.yourOtherDevicesAlreadySync"),
                    systemImage: syncsWithICloud ? "checkmark.icloud" : "exclamationmark.icloud"
                )
                .font(.footnote)
                .foregroundStyle(syncsWithICloud ? Color.secondary : Color.orange)
                .frame(maxWidth: 360)
            }
            Text("onboarding.youCanChangeThisIn")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .task { hasEventsInICloud = await hasSyncedBefore() }
    }

    private var importPage: some View {
        OnboardingPage(
            symbol: "person.2.crop.square.stack.fill",
            title: "onboarding.neverMissABirthday",
            text: "onboarding.bringInBirthdaysAndAnniversaries"
        ) {
            Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .buttonStyle(.glass)
        }
    }

    private var birthdayPage: some View {
        OnboardingPage(
            symbol: "birthday.cake.fill",
            title: "onboarding.yourBirthday",
            text: "onboarding.timityCountsDownToIt"
        ) {
            Toggle("onboarding.addMyBirthday", isOn: $setsBirthday.animation())
                .frame(maxWidth: 320)
            if setsBirthday {
                DatePicker("onboarding.born", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                    .frame(maxWidth: 320)
            }
        }
    }

    private var suggestions: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.top, 32)
                Text("onboarding.startWithAFewMoments")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(EventTemplate.allCases) { template in
                        if let draft = template.draft(region: holidayRegion), template != .vacation {
                            Button {
                                if chosen.contains(template) { chosen.remove(template) } else { chosen.insert(template) }
                            } label: {
                                HStack {
                                    TemplateRow(template: template, title: draft.title)
                                    Spacer()
                                    Image(systemName: chosen.contains(template) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(chosen.contains(template) ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                                }
                                .padding(12)
                                .background(.background.secondary, in: .rect(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(chosen.contains(template) ? .isSelected : [])
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: chosen)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func finish(addingSuggestions: Bool) {
        guard addingSuggestions else {
            onFinish([], nil)
            dismiss()
            return
        }
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
        onFinish(events, setsBirthday ? birthday : nil)
        dismiss()
    }
}

private struct OnboardingPage<Accessory: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: symbol)
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.top, 48)
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                accessory
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 100)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

extension OnboardingPage where Accessory == EmptyView {
    init(symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) {
        self.init(symbol: symbol, title: title, text: text) { EmptyView() }
    }
}
