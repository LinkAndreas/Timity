import SwiftUI
import TipKit

/// Which part of the events a view shows: both side by side, or one column of
/// the app's own split view on iPad.
enum EventsColumns {
    case both, list, detail
}

extension EnvironmentValues {
    /// Whether the events are a tab on iPhone, where the tab bar's + adds events
    /// and search lives in the list; on iPad, the toolbar adds and the sidebar searches.
    @Entry var eventsAreTab = false
}

/// The events: a list beside the selected event on iPad, a stack on iPhone.
struct EventsView<Detail: View, Editor: View, Importer: View, CloudSync: View>: View {
    /// Builds the page for an event, given what to do on Edit and Delete.
    typealias DetailFactory = (EventSnapshot, _ onEdit: @escaping () -> Void, _ onDelete: @escaping () -> Void) -> Detail
    /// Builds the editor for an event, or for a new one from a template, given what to do on Save.
    typealias EditorFactory = (EventSnapshot?, EventDraft?, _ onSave: @escaping (EventSnapshot) -> Void) -> Editor

    let repository: any EventRepository
    @Bindable var navigation: EventsNavigation
    @Binding var options: AppSettings.EventListOptions
    /// How iCloud sync is doing, shown at the end of the list.
    let syncState: () -> CloudSyncState
    let detail: DetailFactory
    let editor: EditorFactory
    let importer: () -> Importer
    /// The iCloud page, opened from the sync status.
    let cloudSync: () -> CloudSync
    var columns = EventsColumns.both

    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var isConfirmingDeleteSelected = false
    @State private var editing: EventSnapshot?
    @State private var isShowingCloudSync = false
    @State private var searchText = ""
    @Environment(\.eventsAreTab) private var eventsAreTab

    var body: some View {
        switch columns {
        case .both:
            // A stack, not a split view: on its side, the largest iPhone counts
            // as wide, and the events would split into columns beside the tabs.
            NavigationStack {
                listColumn
                    .navigationDestination(item: $navigation.selectedEventID) { _ in
                        detailColumn
                    }
            }
        case .list:
            listColumn
        case .detail:
            detailColumn
        }
    }

    /// The selected event, and editing it.
    private var detailColumn: some View {
        let events = repository.events
        return Group {
            if let event = events.first(where: { $0.id == navigation.selectedEventID }) {
                detail(event, { editing = event }, { deleteAfterClosing(event) })
                    .id(event.id)
            } else {
                ContentUnavailableView(
                    "events.selectAnEvent",
                    systemImage: "calendar",
                    description: Text("events.chooseAnEventToSee")
                )
            }
        }
        .sheet(item: $editing) { event in
            editor(event, nil) { repository.save($0) }
        }
    }

    /// The list, its toolbar and the sheets it opens.
    private var listColumn: some View {
        let events = repository.events

        return EventList(
                events: isSearching ? matches(events) : visibleEvents(events),
                selection: $navigation.selectedEventID,
                isSelecting: isSelecting,
                selectedIDs: $selectedIDs,
                sort: options.sort,
                showsPastEvents: isSearching || options.showsPastEvents,
                searchText: trimmedSearch,
                onAdd: { navigation.isAddingEvent = true },
                onImport: { navigation.isImporting = true },
                onEdit: { editing = $0 },
                onSave: { repository.save($0) },
                onDelete: delete,
                status: {
                    let state = syncState()
                    if state.isEnabled {
                        Button { isShowingCloudSync = true } label: {
                            CloudSyncStatusLabel(state: state)
                                .font(.footnote)
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            )
            // The hints follow the events: pinning once there are a few, search once there are many.
            .task(id: events.count) {
                PinEventTip.eventCount = events.count
                SearchEventsTip.eventCount = events.count
            }
            .onChange(of: events.contains(where: \.isPinned), initial: true) { _, hasPinned in
                PinEventTip.hasPinned = hasPinned
            }
            .onChange(of: isSearching) { _, searching in
                if searching { SearchEventsTip().invalidate(reason: .actionPerformed) }
            }
            // While selecting, the delete button waits at the bottom.
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isSelecting {
                        Button(role: .destructive) {
                            isConfirmingDeleteSelected = true
                        } label: {
                            Label(selectedIDs.isEmpty ? String(localized: "common.delete") : String(localized: "events.delete \(selectedIDs.count)"), systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .disabled(selectedIDs.isEmpty)
                        .confirmationDialog(
                            selectedIDs.count == 1 ? String(localized: "common.deleteEvent") : String(localized: "events.deleteEvents \(selectedIDs.count)"),
                            isPresented: $isConfirmingDeleteSelected,
                            titleVisibility: .visible
                        ) {
                            Button(selectedIDs.count == 1 ? String(localized: "common.deleteEvent2") : String(localized: "events.deleteEvents2 \(selectedIDs.count)"), role: .destructive) {
                                deleteSelected()
                            }
                        } message: {
                            Text("events.theEventsAreDeletedOn")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .modifier(PullDownSearch(isEnabled: eventsAreTab, text: $searchText))
            .navigationTitle(isSelecting ? selectionTitle : options.selectedList ?? String(localized: "common.events"))
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
            .toolbar {
                if isSelecting {
                    selectionToolbar(visible: visibleEvents(events))
                } else {
                    toolbar(listNames: events.listNames)
                }
            }
        .sheet(isPresented: $navigation.isAddingEvent) {
            editor(nil, navigation.pendingTemplate) { saved in
                repository.save(saved)
                navigation.selectedEventID = saved.id
            }
            .onDisappear { navigation.pendingTemplate = nil }
        }
        .sheet(isPresented: $navigation.isImporting) {
            importer()
        }
        .sheet(isPresented: $isShowingCloudSync) {
            NavigationStack {
                cloudSync()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .close) { isShowingCloudSync = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $navigation.isShowingYearInReview) {
            YearInReviewView(events: events)
        }
        .sheet(item: $editing) { event in
            editor(event, nil) { repository.save($0) }
        }
    }

    /// Events in the chosen list; archived ones only when asked for.
    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var isSearching: Bool {
        !trimmedSearch.isEmpty
    }

    /// Every event whose name or notes match, whatever list, archived or past.
    private func matches(_ events: [EventSnapshot]) -> [EventSnapshot] {
        events.filter {
            $0.title.localizedStandardContains(trimmedSearch) || $0.notes.localizedStandardContains(trimmedSearch)
        }
    }

    private func visibleEvents(_ events: [EventSnapshot]) -> [EventSnapshot] {
        events.filter { event in
            (options.selectedList == nil || event.listName == options.selectedList) &&
            (!event.isArchived || options.showsArchivedEvents)
        }
    }

    private var selectionTitle: String {
        selectedIDs.isEmpty ? String(localized: "events.selectEvents") : String(localized: "events.selected \(selectedIDs.count)")
    }

    private func deleteSelected() {
        if let selected = navigation.selectedEventID, selectedIDs.contains(selected) {
            navigation.selectedEventID = nil
        }
        withAnimation {
            for id in selectedIDs { repository.delete(id) }
        }
        selectedIDs = []
        isSelecting = false
    }

    @ToolbarContentBuilder
    private func selectionToolbar(visible: [EventSnapshot]) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            let all = Set(visible.map(\.id))
            Button(selectedIDs.isSuperset(of: all) && !all.isEmpty ? LocalizedStringKey("common.deselectAll") : LocalizedStringKey("common.selectAll")) {
                selectedIDs = selectedIDs.isSuperset(of: all) ? [] : all
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("common.done") {
                withAnimation {
                    isSelecting = false
                    selectedIDs = []
                }
            }
        }
    }

    private func delete(_ event: EventSnapshot) {
        if navigation.selectedEventID == event.id { navigation.selectedEventID = nil }
        withAnimation { repository.delete(event.id) }
    }

    /// Closes the event's page first, then deletes it once it's gone, so the page
    /// never shows an event that no longer exists.
    private func deleteAfterClosing(_ event: EventSnapshot) {
        navigation.selectedEventID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation { repository.delete(event.id) }
        }
    }

    @ToolbarContentBuilder
    private func toolbar(listNames: [String]) -> some ToolbarContent {
        if !eventsAreTab {
            ToolbarItem(placement: .primaryAction) {
                Button("common.addEvent", systemImage: "plus") {
                    navigation.isAddingEvent = true
                }
            }
        }
        // Its own pill, just before the icon buttons.
        ToolbarItem(placement: .topBarTrailing) {
            Button("events.select") {
                withAnimation { isSelecting = true }
            }
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Menu("events.sortAndFilter", systemImage: "line.3.horizontal.decrease") {
                Picker("events.sortBy", selection: $options.sort) {
                    ForEach(AppSettings.EventSort.allCases) { sort in
                        Text(sort.name).tag(sort)
                    }
                }
                if !listNames.isEmpty {
                    Picker("common.list", selection: $options.selectedList) {
                        Label("events.allEvents", systemImage: "tray.full").tag(String?.none)
                        ForEach(listNames, id: \.self) { name in
                            Label(name, systemImage: "list.bullet").tag(Optional(name))
                        }
                    }
                }
                Toggle("events.showPastEvents", isOn: $options.showsPastEvents)
                Toggle("events.showArchivedEvents", isOn: $options.showsArchivedEvents)
            }
        }
        // Things done now and then, last.
        ToolbarItem(placement: .topBarTrailing) {
            Menu("events.more", systemImage: "ellipsis") {
                Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down") {
                    navigation.isImporting = true
                }
                Button("common.yearInReview", systemImage: "chart.bar.xaxis") {
                    navigation.isShowingYearInReview = true
                }
            }
        }
    }
}

/// A search field hidden under the title until the list is pulled down, as in
/// Mail and Notes.
private struct PullDownSearch: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "common.searchEventsNotes")
        } else {
            content
        }
    }
}

/// The list of events in sections: pinned, upcoming and past.
struct EventList<Status: View>: View {
    let events: [EventSnapshot]
    @Binding var selection: UUID?
    /// Whether events are being picked, e.g. to delete several at once.
    var isSelecting = false
    @Binding var selectedIDs: Set<UUID>
    let sort: AppSettings.EventSort
    let showsPastEvents: Bool
    /// What's searched for; nothing found shows as such, not as an empty list.
    var searchText = ""
    let onAdd: () -> Void
    let onImport: () -> Void
    let onEdit: (EventSnapshot) -> Void
    /// Saves a changed event, e.g. pinned or archived.
    let onSave: (EventSnapshot) -> Void
    let onDelete: (EventSnapshot) -> Void
    /// A quiet line at the end of the list, such as how iCloud sync is doing.
    @ViewBuilder let status: () -> Status

    @State private var deleting: EventSnapshot?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Cards on iPhone; the iPad's list column keeps its grouped rows.
    @Environment(\.eventsAreTab) private var eventsAreTab

    var body: some View {
        // Day counts change at midnight, and today's events move to the past during the day.
        TimelineView(.everyMinute) { context in
            let sections = EventSections(events: events, now: context.date, sort: sort)
            // With the iPhone on its side, cards side by side, as in TestFlight.
            if verticalSizeClass == .compact {
                grid(sections, now: context.date)
            } else {
                list(sections, now: context.date)
            }
        }
        .overlay {
            if events.isEmpty, !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if events.isEmpty {
                ContentUnavailableView {
                    Label("events.noEventsYet", systemImage: "calendar.badge.plus")
                } description: {
                    Text("events.addBirthdaysTripsAndDeadlines")
                } actions: {
                    Button("common.addEvent", systemImage: "plus", action: onAdd)
                        .buttonStyle(.glassProminent)
                    Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down", action: onImport)
                        .buttonStyle(.glass)
                    // On a new device, events may still be on their way from iCloud.
                    status()
                        .padding(.top, 8)
                }
            }
        }
        .confirmationDialog(
            "common.deleteEvent",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { event in
            Button("common.delete2 \(event.title)", role: .destructive) { onDelete(event) }
        } message: { _ in
            Text("common.theEventIsDeletedOn")
        }
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// Hints only over the whole list, not while searching or picking events.
    private var showsTips: Bool {
        !isSelecting && searchText.isEmpty && !events.isEmpty
    }

    /// Each event a card of its own on iPhone, spaced apart.
    private func list(_ sections: EventSections, now: Date) -> some View {
        let showsPast = showsPastEvents
        // The sync status sits under the last section, close to the last event.
        let last: ListPart? = if !sections.archived.isEmpty { .archived }
            else if showsPast, !sections.past.isEmpty { .past }
            else if !sections.upcoming.isEmpty { .upcoming }
            else if !sections.pinned.isEmpty { .pinned }
            else { nil }
        return List(selection: listSelection) {
            if showsTips {
                Section {
                    TipView(PinEventTip())
                    TipView(SearchEventsTip())
                }
            }

            // While selecting, pinned events are rows like the others, so they can be picked.
            if isSelecting, !sections.pinned.isEmpty {
                Section {
                    rows(sections.pinned, now: now)
                } header: {
                    Text("common.pinned")
                } footer: {
                    statusFooter(if: last == .pinned)
                }
            } else if !sections.pinned.isEmpty {
                Section {
                    PinnedEventsCarousel(events: sections.pinned, now: now, selection: $selection)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    statusFooter(if: last == .pinned)
                }
            }

            if !sections.upcoming.isEmpty {
                Section {
                    rows(sections.upcoming, now: now)
                } header: {
                    Text("events.upcoming")
                } footer: {
                    statusFooter(if: last == .upcoming)
                }
            }

            if showsPast, !sections.past.isEmpty {
                Section {
                    rows(sections.past, now: now)
                } header: {
                    Text("events.past")
                } footer: {
                    statusFooter(if: last == .past)
                }
            }

            if !sections.archived.isEmpty {
                Section {
                    rows(sections.archived, now: now)
                } header: {
                    Text("common.archived")
                } footer: {
                    statusFooter(if: last == .archived)
                }
            }
        }
        .listRowSpacing(eventsAreTab ? 12 : nil)
    }

    private enum ListPart {
        case pinned, upcoming, past, archived
    }

    @ViewBuilder
    private func statusFooter(if isLast: Bool) -> some View {
        if isLast {
            status()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    /// Two or more columns of cards, with the same sections as the list.
    private func grid(_ sections: EventSections, now: Date) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if showsTips {
                    TipView(PinEventTip())
                    TipView(SearchEventsTip())
                }
                // While selecting, pinned events are cards like the others, so they can be picked.
                if isSelecting {
                    gridSection("common.pinned", sections.pinned, now: now)
                } else if !sections.pinned.isEmpty {
                    PinnedEventsCarousel(events: sections.pinned, now: now, selection: $selection)
                }
                gridSection("events.upcoming", sections.upcoming, now: now)
                if showsPastEvents {
                    gridSection("events.past", sections.past, now: now)
                }
                gridSection("common.archived", sections.archived, now: now)
                if !events.isEmpty {
                    status()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func gridSection(_ title: LocalizedStringKey, _ events: [EventSnapshot], now: Date) -> some View {
        if !events.isEmpty {
            GridSection(title) {
                ForEach(events) { event in
                    card(event, now: now)
                }
            }
        }
    }

    private func card(_ event: EventSnapshot, now: Date) -> some View {
        let isPicked = selectedIDs.contains(event.id)
        return Button {
            if isSelecting {
                if isPicked { selectedIDs.remove(event.id) } else { selectedIDs.insert(event.id) }
            } else {
                selection = event.id
            }
        } label: {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isPicked ? Color.accentColor : Color.secondary)
                }
                EventRow(event: event, countdown: event.countdown(at: now))
            }
            .gridCard()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .contextMenu {
            EventActions(event: event, onEdit: onEdit, onSave: onSave, onDelete: { deleting = $0 })
        } preview: {
            EventPreviewCard(event: event, now: now)
        }
    }

    /// One event shown beside the list, or the events picked while selecting.
    private var listSelection: Binding<Set<UUID>> {
        Binding(
            get: { isSelecting ? selectedIDs : Set([selection].compactMap { $0 }) },
            set: { picked in
                if isSelecting {
                    selectedIDs = picked
                } else {
                    selection = picked.first
                }
            }
        )
    }

    private func rows(_ events: [EventSnapshot], now: Date) -> some View {
        ForEach(events) { event in
            EventRow(event: event, countdown: event.countdown(at: now))
                .tag(event.id)
                .swipeActions(edge: .leading) {
                    Button(event.isPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
                        withAnimation { onSave(event.togglingPin()) }
                    }
                    .tint(.orange)
                }
                // A full swipe deletes, as in Mail and Reminders.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("common.delete", systemImage: "trash", role: .destructive) { onDelete(event) }
                    Button(event.isArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                           systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
                        toggleArchive(event)
                    }
                    .tint(.indigo)
                    Button("common.edit", systemImage: "pencil") { onEdit(event) }
                }
                .contextMenu {
                    EventActions(event: event, onEdit: onEdit, onSave: onSave, onDelete: { deleting = $0 })
                } preview: {
                    EventPreviewCard(event: event, now: now)
                }
        }
    }

    private func toggleArchive(_ event: EventSnapshot) {
        let archived = event.togglingArchive()
        withAnimation { onSave(archived) }
        if archived.isArchived, selection == event.id { selection = nil }
    }
}

nonisolated extension EventSnapshot {
    func togglingPin() -> EventSnapshot {
        var event = self
        event.isPinned.toggle()
        event.modifiedAt = .now
        return event
    }

    func togglingArchive() -> EventSnapshot {
        var event = self
        event.isArchived.toggle()
        event.modifiedAt = .now
        return event
    }
}

/// The actions every event offers in menus.
struct EventActions: View {
    let event: EventSnapshot
    let onEdit: (EventSnapshot) -> Void
    let onSave: (EventSnapshot) -> Void
    let onDelete: (EventSnapshot) -> Void

    var body: some View {
        Button("common.edit", systemImage: "pencil") { onEdit(event) }
        Button(event.isPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
            onSave(event.togglingPin())
        }
        Button(event.isArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
               systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
            onSave(event.togglingArchive())
        }
        ShareLink(item: EventShareText.text(for: event))
        ShareLink(item: EventFileTransfer(event: event), preview: SharePreview(event.title)) {
            Label("common.sendACopy", systemImage: "paperplane")
        }
        Divider()
        Button("common.delete", systemImage: "trash", role: .destructive) { onDelete(event) }
    }
}

/// Events split into the list's sections and sorted by the user's choice.
nonisolated struct EventSections {
    var pinned: [EventSnapshot] = []
    var upcoming: [EventSnapshot] = []
    var past: [EventSnapshot] = []
    var archived: [EventSnapshot] = []

    init(events: [EventSnapshot], now: Date, sort: AppSettings.EventSort) {
        let countdowns = Dictionary(events.map { ($0.id, $0.countdown(at: now)) }, uniquingKeysWith: { first, _ in first })
        func countdown(_ event: EventSnapshot) -> Countdown { countdowns[event.id]! }

        func sorted(_ events: [EventSnapshot], pastFirstByRecent: Bool) -> [EventSnapshot] {
            switch sort {
            case .date:
                events.sorted {
                    pastFirstByRecent
                        ? countdown($0).target > countdown($1).target
                        : countdown($0).target < countdown($1).target
                }
            case .title:
                events.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            case .created:
                events.sorted { $0.createdAt > $1.createdAt }
            }
        }

        archived = sorted(events.filter(\.isArchived), pastFirstByRecent: true)
        let active = events.filter { !$0.isArchived }
        pinned = sorted(active.filter(\.isPinned), pastFirstByRecent: false)
        let unpinned = active.filter { !$0.isPinned }
        upcoming = sorted(unpinned.filter { countdown($0).direction != .past || countdown($0).isToday }, pastFirstByRecent: false)
        past = sorted(unpinned.filter { countdown($0).direction == .past && !countdown($0).isToday }, pastFirstByRecent: true)
    }
}

nonisolated enum EventShareText {
    static func text(for event: EventSnapshot, now: Date = .now) -> String {
        let countdown = event.countdown(at: now)
        return "\(event.title) — \(CountdownText.relativeDays(countdown)) (\(countdown.targetText))"
    }
}
