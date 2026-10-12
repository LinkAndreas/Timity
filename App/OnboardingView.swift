import SwiftData
import SwiftUI
import WidgetKit

/// A short welcome: what Timity does, birthdays from Contacts, the user's own
/// birthday for Life in Weeks, and a few events to start with.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var page = 0
    @State private var isImporting = false
    @State private var birthday = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var setsBirthday = false
    @State private var chosen: Set<EventTemplate> = [.newYearsEve, .nextHoliday]

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                welcome.tag(0)
                importPage.tag(1)
                birthdayPage.tag(2)
                suggestions.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finish(addingSuggestions: false) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if page < 3 {
                        withAnimation { page += 1 }
                    } else {
                        finish(addingSuggestions: true)
                    }
                } label: {
                    Text(page < 3 ? LocalizedStringKey("Continue") : LocalizedStringKey("Start Counting"))
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
            ImportView()
        }
    }

    private var welcome: some View {
        OnboardingPage(
            symbol: "hourglass",
            title: "Welcome to Timity",
            text: "Count down to birthdays, trips and deadlines — and see how long since the moments that matter. Your events sync through iCloud to your iPhone, iPad and Apple Watch."
        )
    }

    private var importPage: some View {
        OnboardingPage(
            symbol: "person.2.crop.square.stack.fill",
            title: "Never Miss a Birthday",
            text: "Bring in birthdays and anniversaries from Contacts and upcoming events from Calendar. You choose which ones."
        ) {
            Button("Import Birthdays and Events", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
            .buttonStyle(.glass)
        }
    }

    private var birthdayPage: some View {
        OnboardingPage(
            symbol: "birthday.cake.fill",
            title: "Your Birthday",
            text: "Timity counts down to it every year, and Life in Weeks draws every week of your life. It stays private to you."
        ) {
            Toggle("Add My Birthday", isOn: $setsBirthday.animation())
                .frame(maxWidth: 320)
            if setsBirthday {
                DatePicker("Born", selection: $birthday, in: ...Date.now, displayedComponents: .date)
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
                Text("Start with a Few Moments")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(EventTemplate.allCases) { template in
                        if let draft = template.draft(region: settings.holidayRegion), template != .vacation {
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
        if addingSuggestions {
            for template in EventTemplate.allCases where chosen.contains(template) {
                guard let draft = template.draft(region: settings.holidayRegion) else { continue }
                let event = Event(title: draft.trimmedTitle, date: draft.date)
                draft.apply(to: event)
                modelContext.insert(event)
            }
            if setsBirthday {
                settings.birthday = birthday
                var draft = EventDraft()
                draft.title = String(localized: "My Birthday")
                draft.date = birthday
                draft.isAllDay = true
                draft.recurrence = .yearly
                draft.symbolName = "birthday.cake.fill"
                draft.color = .pink
                let event = Event(title: draft.title, date: birthday)
                draft.apply(to: event)
                event.isPinned = true
                modelContext.insert(event)
            }
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        settings.hasCompletedOnboarding = true
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
