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
        // Woken to take in a change from the iPhone, such as iCloud sync turned off.
        .backgroundTask(.watchConnectivity) {
            await PhoneSyncSetting.receivePendingContent()
        }
    }
}

/// The Watch app's composition root: it holds what lives as long as the app and
/// builds everything else where it's needed.
@MainActor
final class WatchComposition {
    private let database: EventDatabase
    private let repository: SwiftDataEventRepository
    private let sharedSettings: SharedSettings
    private let cloudSync: CloudKitSyncMonitor
    private let syncSetting = PhoneSyncSetting()
    /// Whether the iPhone's latest word has been taken in since launch.
    private var hasHeardFromPhone = false

    init() {
        let stored = syncSetting.state
        // Without iCloud until the iPhone's latest word is in: it may have turned
        // sync off while this app wasn't running.
        database = EventDatabase(syncsWithICloud: false)
        sharedSettings = SharedSettings(store: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        repository = SwiftDataEventRepository(database: database)
        // Meanwhile the status reads as checking, not as a store that couldn't sync.
        cloudSync = CloudKitSyncMonitor(isEnabled: stored.syncsWithICloud, storeSyncs: true, containerIdentifier: AppGroup.cloudContainer)
        cloudSync.setAwaitsPhone(stored.awaitsPhone)
        cloudSync.start()
        syncSetting.start { [weak self] state in self?.syncSettingChanged(state) }
        // Should WatchConnectivity not come up, the setting last heard holds.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, !self.hasHeardFromPhone else { return }
            self.syncSettingChanged(self.syncSetting.state)
        }
        IntentDependencies.register(
            repository: repository,
            reader: SwiftDataEventReader(database: database),
            widgets: WidgetKitRefresher(),
            sharedSettings: sharedSettings
        )
        #if DEBUG
        ScreenshotSamples.addIfAsked(to: repository)
        #endif
    }

    /// Opens the store again with or without iCloud, as the iPhone now does; the
    /// events on this Watch stay, and sync once it does.
    private func syncSettingChanged(_ state: PhoneSyncSetting.State) {
        hasHeardFromPhone = true
        cloudSync.setAwaitsPhone(state.awaitsPhone)
        let isOn = state.syncsWithICloud
        if isOn != database.syncsWithICloud {
            database.reopen(syncsWithICloud: isOn)
            repository.reload()
            WidgetKitRefresher().reloadAll()
        }
        if isOn != cloudSync.state.isEnabled || cloudSync.state.storeSyncs != database.syncsWithICloud {
            cloudSync.setEnabled(isOn, storeSyncs: database.syncsWithICloud)
        }
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
        }, onDelete: { [repository] id in
            repository.delete(id)
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
    /// Deletes an event on every device.
    let onDelete: (UUID) -> Void
    @ViewBuilder let sun: () -> Sun

    @State private var path: [UUID] = []
    @State private var isAdding = false

    var body: some View {
        let events = repository.events

        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let sorted = sortedEvents(events, at: context.date)

                List {
                    // Part of the list rather than over it, so it scrolls on small
                    // watches and the sync status below it stays reachable.
                    if events.isEmpty {
                        ContentUnavailableView {
                            Label("common.noEvents", systemImage: "calendar.badge.plus")
                        } description: {
                            if syncState().isEnabled {
                                Text("watch.addEventsInTimityOn")
                            } else {
                                Text("watch.icloudSyncIsOffIn")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }

                    ForEach(Array(sorted.enumerated()), id: \.element.id) { index, event in
                        let link = NavigationLink(value: event.id) {
                            WatchEventRow(event: event, now: context.date)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(event.color.color.gradient.opacity(0.35))
                        )
                        // A swipe deletes, as in Mail and Reminders.
                        .swipeActions(edge: .trailing) {
                            Button("common.delete", systemImage: "trash", role: .destructive) {
                                withAnimation { onDelete(event.id) }
                            }
                        }
                        // Double tap opens the first event, the next one to come.
                        if index == 0 {
                            link.handGestureShortcut(.primaryAction)
                        } else {
                            link
                        }
                    }

                    Section {
                        WatchSyncStatus(state: syncState())
                    }
                }
            }
            .navigationTitle("common.timity")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.addEvent", systemImage: "plus") {
                        isAdding = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        sun()
                    } label: {
                        Label("common.sun", systemImage: "sun.horizon.fill")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    WatchEventDetail(event: event) {
                        // Back to the list first, so the page never shows an event that's gone.
                        path.removeAll()
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            withAnimation { onDelete(id) }
                        }
                    }
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

    /// Pinned events first, then the others, each soonest first.
    private func sortedEvents(_ events: [EventSnapshot], at now: Date) -> [EventSnapshot] {
        let sorted = events.active.sortedByCountdown(at: now)
        return sorted.filter(\.isPinned) + sorted.filter { !$0.isPinned }
    }
}

/// A quiet line on iCloud sync; tapping it explains a problem.
private struct WatchSyncStatus: View {
    let state: CloudSyncState

    var body: some View {
        NavigationLink {
            WatchSyncDetail(state: state)
        } label: {
            CloudSyncStatusLabel(state: state)
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .listRowBackground(Color.clear)
    }
}

private struct WatchEventRow: View {
    let event: EventSnapshot
    let now: Date

    var body: some View {
        let countdown = event.countdown(at: now)

        HStack(spacing: 8) {
            Image(systemName: event.symbolName)
                .accessibilityHidden(true)
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
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let countdown = event.countdown(at: context.date)
            let breakdown = countdown.breakdown(includeWeeks: true)

            ScrollView {
                VStack(spacing: 10) {
                    Image(systemName: event.symbolName)
                        .accessibilityHidden(true)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(event.color.gradient, in: .circle)

                    if countdown.isToday {
                        Text("common.today")
                            .scaledFont(size: 40, weight: .heavy, design: .rounded, relativeTo: .title)
                    } else {
                        VStack(spacing: -4) {
                            Text(countdown.days, format: .number)
                                .scaledFont(size: 52, weight: .heavy, design: .rounded)
                                .monospacedDigit()
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText(countsDown: countdown.direction == .future))
                            Text(CountdownText.dayCaption(countdown))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
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
                                            .scaledFont(size: 10, weight: .semibold, relativeTo: .caption2, maxScale: 2)
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

                    Button("common.deleteEvent2", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 4)
            }
            .animation(.snappy, value: breakdown)
        }
        .navigationTitle(event.title)
        .containerBackground(event.color.color.gradient.opacity(0.4), for: .navigation)
        .confirmationDialog("common.deleteEvent", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("common.delete2 \(event.title)", role: .destructive, action: onDelete)
        } message: {
            Text("common.theEventIsDeletedOn")
        }
    }
}

/// Adds an event from the Watch — the name by dictation or Scribble, the day and, optionally, a time.
struct WatchAddEventView: View {
    let onAdd: (EventSnapshot) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    /// A week from now at 9:00, the time used once All-Day is switched off.
    @State private var date = Calendar.autoupdatingCurrent.date(
        bySettingHour: 9, minute: 0, second: 0,
        of: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 7, to: .now) ?? .now
    ) ?? .now
    @State private var repeatsYearly = false
    @State private var isAllDay = true

    /// A century either way: enough for birthdays and plans, and the year wheel starts somewhere near.
    private static let range: ClosedRange<Date> = {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        return (calendar.date(byAdding: .year, value: -100, to: now) ?? now)...(calendar.date(byAdding: .year, value: 100, to: now) ?? now)
    }()

    var body: some View {
        NavigationStack {
            // A scrolling column rather than a Form: in a list the Watch turns each wheel column into a
            // list of its own, presented over the sheet one after the other; here they're the
            // system's wheels, turned with the Digital Crown, with nothing presented.
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("common.name", text: $name)
                    Text("common.date")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    DatePicker("common.date", selection: $date, in: Self.range, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(height: 84)
                    // As on the iPhone: all-day unless switched off, which adds a time.
                    Toggle("common.allDay", isOn: $isAllDay.animation())
                    if !isAllDay {
                        DatePicker("common.time", selection: $date, in: Self.range, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 84)
                    }
                    Toggle("common.everyYear", isOn: $repeatsYearly)
                    Button("common.addEvent", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, 4)
                }
            }
            .navigationTitle("common.newEvent")
        }
    }

    private func add() {
        var event = EventSnapshot(
            title: name.trimmingCharacters(in: .whitespacesAndNewlines),
            isAllDay: isAllDay,
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
                    .accessibilityHidden(true)
                    .scaledFont(size: 40, relativeTo: .title)
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.pulse, isActive: state.isSyncing)
                    .foregroundStyle(state.statusTint ?? .accentColor)
                    .padding(.bottom, 2)
                state.statusText
                    .font(.headline)
                Group {
                    if state.isEnabled {
                        Text(state.problem?.advice ?? "common.yourEventsSyncWithYour")
                    } else if state.awaitsPhone {
                        Text("watch.openTimityOnYourIPhone")
                    } else {
                        Text("watch.icloudSyncIsOffIn")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                if let details = state.problemDetails {
                    Text(verbatim: details)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                if state.problem != nil, let lastSynced = state.lastSynced {
                    CloudSyncState.lastSyncedText(lastSynced)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .navigationTitle("common.icloud")
    }
}
