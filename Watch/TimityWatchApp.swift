import SwiftUI

@main
struct TimityWatchApp: App {
    @State private var composition = WatchComposition()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            composition.rootView()
        }
        .onChange(of: scenePhase) { _, phase in
            composition.scenePhaseChanged(to: phase)
        }
    }
}

/// The Watch app's composition root: it holds what lives as long as the app and
/// builds everything else where it's needed.
@MainActor
final class WatchComposition {
    private let repository: SwiftDataEventRepository
    private let sharedSettings: SharedSettings
    private let cloudSync: CloudKitSyncMonitor

    init() {
        let database = EventDatabase(syncsWithICloud: true)
        sharedSettings = SharedSettings(store: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        repository = SwiftDataEventRepository(database: database)
        cloudSync = CloudKitSyncMonitor(isEnabled: true, storeSyncs: database.syncsWithICloud, containerIdentifier: AppGroup.cloudContainer)
        cloudSync.start()
        IntentDependencies.register(
            repository: repository,
            reader: SwiftDataEventReader(database: database),
            widgets: WidgetKitRefresher(),
            sharedSettings: sharedSettings
        )
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        // Complications catch up with events that synced while the app was away.
        if phase == .background { WidgetKitRefresher().reloadAll() }
        if phase == .active {
            repository.reload()
            Task { await cloudSync.checkAccount() }
        }
    }

    func rootView() -> some View {
        WatchEventList(repository: repository, syncState: { [cloudSync] in cloudSync.state }, onAdd: { [repository] event in
            repository.save(event)
            WidgetKitRefresher().reloadAll()
        }) { [sharedSettings] in
            // A location manager only while the Sun screen is open. Finding the
            // place here also gives the Sun complication its place.
            WithState {
                SunPlaceModel(place: sharedSettings.place, locator: CoreLocationPlaceLocator()) { place in
                    sharedSettings.place = place
                    WidgetKitRefresher().reload(.sun)
                }
            } content: { place in
                WatchSunView(location: place)
            }
        }
    }
}

/// The events, soonest first, synced from iPhone and iPad through iCloud.
struct WatchEventList<Sun: View>: View {
    let repository: any EventRepository
    /// How iCloud sync is doing, shown at the end of the list.
    let syncState: () -> CloudSyncState
    let onAdd: (EventSnapshot) -> Void
    @ViewBuilder let sun: () -> Sun

    @State private var path: [UUID] = []
    @State private var isAdding = false

    var body: some View {
        let events = repository.events

        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let sorted = sortedEvents(events, at: context.date)

                List {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, event in
                        let link = NavigationLink(value: event.id) {
                            WatchEventRow(event: event, now: context.date)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(event.color.color.gradient.opacity(0.35))
                        )
                        // Double tap opens the first event, the next one to come.
                        if index == 0 {
                            link.handGestureShortcut(.primaryAction)
                        } else {
                            link
                        }
                    }

                    Section {
                        syncStatus
                    }
                }
                .overlay {
                    if events.isEmpty {
                        ContentUnavailableView {
                            Label("No Events", systemImage: "calendar.badge.plus")
                        } description: {
                            Text("Add events in Timity on your iPhone or iPad. They appear here through iCloud.")
                        } actions: {
                            syncStatus
                        }
                    }
                }
            }
            .navigationTitle("Timity")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add Event", systemImage: "plus") {
                        isAdding = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        sun()
                    } label: {
                        Label("Sun", systemImage: "sun.horizon.fill")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    WatchEventDetail(event: event)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            WatchAddEventView(onAdd: onAdd)
        }
        .onOpenURL { url in
            if let id = DeepLink.eventID(in: url) { path = [id] }
        }
    }

    /// A quiet line on iCloud sync; tapping it explains a problem.
    private var syncStatus: some View {
        let state = syncState()
        return NavigationLink {
            WatchSyncDetail(state: state)
        } label: {
            CloudSyncStatusLabel(state: state)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .listRowBackground(Color.clear)
    }

    /// Pinned events first, then the others, each soonest first.
    private func sortedEvents(_ events: [EventSnapshot], at now: Date) -> [EventSnapshot] {
        let sorted = events.active.sortedByCountdown(at: now)
        return sorted.filter(\.isPinned) + sorted.filter { !$0.isPinned }
    }
}

private struct WatchEventRow: View {
    let event: EventSnapshot
    let now: Date

    var body: some View {
        let countdown = event.countdown(at: now)

        HStack(spacing: 8) {
            Image(systemName: event.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(event.color.color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(CountdownText.relativeDays(countdown))
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(countdown.direction == .past ? .secondary : .primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// One event: the days to go and a live breakdown, scrolling with the Digital Crown.
struct WatchEventDetail: View {
    let event: EventSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = event.countdown(at: context.date)
            let breakdown = countdown.breakdown(includeWeeks: true)

            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: event.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(event.color.gradient, in: .circle)

                    if countdown.isToday {
                        Text("Today")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                    } else {
                        VStack(spacing: -4) {
                            Text(countdown.days, format: .number)
                                .font(.system(size: 52, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText(countsDown: countdown.direction == .future))
                            Text(CountdownText.dayCaption(countdown))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(countdown.targetText)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                        let parts = breakdown.parts(includingSeconds: true)
                        ForEach(Array(stride(from: 0, to: parts.count, by: 2)), id: \.self) { index in
                            GridRow {
                                ForEach(parts[index..<min(index + 2, parts.count)]) { part in
                                    VStack(spacing: 0) {
                                        Text(part.value, format: .number)
                                            .font(.headline.monospacedDigit())
                                            .contentTransition(.numericText())
                                        Text(CountdownText.unit(part.unit, value: part.value))
                                            .font(.system(size: 10, weight: .semibold))
                                            .textCase(.uppercase)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(event.color.color.opacity(0.2), in: .rect(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(CountdownText.spokenBreakdown(breakdown, includingSeconds: true))
                }
                .padding(.horizontal, 4)
            }
            .animation(.snappy, value: breakdown)
        }
        .navigationTitle(event.title)
        .containerBackground(event.color.color.gradient.opacity(0.4), for: .navigation)
    }
}

/// Adds an event from the Watch — the name by dictation or Scribble, and the day.
struct WatchAddEventView: View {
    let onAdd: (EventSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var date = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var repeatsYearly = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Toggle("Every Year", isOn: $repeatsYearly)
                Button("Add Event", action: add)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("New Event")
        }
    }

    private func add() {
        var event = EventSnapshot(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines),
            isAllDay: true,
            recurrence: repeatsYearly ? .yearly : .never
        )
        event.setStartDate(date)
        onAdd(event)
        dismiss()
    }
}

/// How iCloud sync is doing, and what to do about a problem.
private struct WatchSyncDetail: View {
    let state: CloudSyncState

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: state.statusSymbol)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, isActive: state.isSyncing)
                    .foregroundStyle(state.statusTint ?? .accentColor)
                    .padding(.bottom, 2)
                state.statusText
                    .font(.headline)
                Text(state.problem?.advice ?? "Your events sync with your iPhone, iPad and Apple Watch through your private iCloud account. Only you can see them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if state.problem != nil, let lastSynced = state.lastSynced {
                    Text("Last synced \(lastSynced, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .navigationTitle("iCloud")
    }
}
