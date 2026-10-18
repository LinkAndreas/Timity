import SwiftUI
import TipKit

/// Which part of the events a view shows: both side by side, or one column of
/// the app's own split view on iPad.
enum EventsColumns {
    case both, list, detail
}

extension EnvironmentValues {
    /// Whether the events are a tab on iPhone, where the tab bar's + adds events;
    /// on iPad, the toolbar adds.
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
            // While selecting, the tab bar makes way for the actions, as in Mail and Photos.
            .tabBarHidden(isSelecting)
            .confirmationDialog(
                pickedIDs(in: events).count == 1 ? String(localized: "common.deleteEvent") : String(localized: "events.deleteEvents \(pickedIDs(in: events).count)"),
                isPresented: $isConfirmingDeleteSelected,
                titleVisibility: .visible
            ) {
                Button(pickedIDs(in: events).count == 1 ? String(localized: "common.deleteEvent2") : String(localized: "events.deleteEvents2 \(pickedIDs(in: events).count)"), role: .destructive) {
                    deleteSelected()
                }
            } message: {
                Text("events.theEventsAreDeletedOn")
            }
            .pullDownSearchable(text: $searchText, prompt: "common.searchEventsNotes")
            .navigationTitle(isSelecting ? selectionTitle(events) : activeList(in: events) ?? String(localized: "common.events"))
            // Wide enough on iPad for the title beside the toolbar's buttons; narrower, it shrank to "Eve…".
            .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 480)
            .toolbar {
                if isSelecting {
                    selectionToolbar(visible: shownEvents(events))
                } else {
                    toolbar(listNames: events.listNames)
                }
            }
        // A delete is one swipe away and reaches every device, so it can be taken back for a moment.
        .overlay(alignment: .bottom) {
            if !navigation.recentlyDeleted.isEmpty {
                UndoDeleteBanner(deleted: navigation.recentlyDeleted) {
                    withAnimation {
                        repository.save(navigation.recentlyDeleted)
                        navigation.recentlyDeleted = []
                    }
                } onExpire: {
                    withAnimation { navigation.recentlyDeleted = [] }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
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

    /// The list chosen in the menu, while any event is still in it; once the last
    /// one has gone, here or on another device, all events show again.
    private func activeList(in events: [EventSnapshot]) -> String? {
        options.selectedList.flatMap { name in events.contains { $0.listName == name } ? name : nil }
    }

    /// Events in the chosen list; archived ones only when asked for.
    private func visibleEvents(_ events: [EventSnapshot]) -> [EventSnapshot] {
        let list = activeList(in: events)
        return events.filter { event in
            (list == nil || event.listName == list) &&
            (!event.isArchived || options.showsArchivedEvents)
        }
    }

    /// The events the list shows right now, which are all selecting can act on:
    /// the matches while searching, and no past events when they're hidden.
    private func shownEvents(_ events: [EventSnapshot], now: Date = .now) -> [EventSnapshot] {
        if isSearching { return matches(events) }
        let visible = visibleEvents(events)
        guard !options.showsPastEvents else { return visible }
        return visible.filter { event in
            let countdown = event.countdown(at: now)
            return event.isPinned || event.isArchived || countdown.direction != .past || countdown.isToday
        }
    }

    /// The selected events still shown, so nothing hidden by search or a filter is changed or deleted.
    private func pickedIDs(in events: [EventSnapshot]) -> Set<UUID> {
        selectedIDs.intersection(shownEvents(events).map(\.id))
    }

    private func selectionTitle(_ events: [EventSnapshot]) -> String {
        let count = pickedIDs(in: events).count
        return count == 0 ? String(localized: "events.selectEvents") : String(localized: "events.selected \(count)")
    }

    private func deleteSelected() {
        let picked = pickedIDs(in: repository.events)
        if let selected = navigation.selectedEventID, picked.contains(selected) {
            navigation.selectedEventID = nil
        }
        withAnimation {
            navigation.recentlyDeleted = repository.events.filter { picked.contains($0.id) }
            for id in picked { repository.delete(id) }
        }
        selectedIDs = []
        isSelecting = false
    }

    @ToolbarContentBuilder
    private func selectionToolbar(visible: [EventSnapshot]) -> some ToolbarContent {
        // What to do with the selection, along the bottom: pin and archive on the left,
        // delete apart on the right, in red, as in Mail and Photos.
        ToolbarItemGroup(placement: .bottomActions) {
            let selected = visible.filter { selectedIDs.contains($0.id) }
            let allPinned = !selected.isEmpty && selected.allSatisfy(\.isPinned)
            let allArchived = !selected.isEmpty && selected.allSatisfy(\.isArchived)
            Button(allPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"), systemImage: allPinned ? "pin.slash" : "pin") {
                updateSelected(selected) { $0.isPinned = !allPinned }
            }
            .disabled(selected.isEmpty)
            Button(allArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                   systemImage: allArchived ? "tray.and.arrow.up" : "archivebox") {
                updateSelected(selected) { $0.isArchived = !allArchived }
            }
            .disabled(selected.isEmpty)
            Spacer()
            Button(role: .destructive) {
                isConfirmingDeleteSelected = true
            } label: {
                Label(selected.isEmpty ? String(localized: "common.delete") : String(localized: "events.delete \(selected.count)"), systemImage: "trash")
                    // With its count, so it's clear how many go.
                    .labelStyle(.titleAndIcon)
            }
            .tint(.red)
            .disabled(selected.isEmpty)
        }
        ToolbarItem(placement: .cancellationAction) {
            let all = Set(visible.map(\.id))
            Button(selectedIDs.isSuperset(of: all) && !all.isEmpty ? LocalizedStringKey("common.deselectAll") : LocalizedStringKey("common.selectAll")) {
                selectedIDs = selectedIDs.isSuperset(of: all) ? [] : all
            }
        }
        // As in Mail: closing and what to do with the selection share one pill.
        ToolbarItem(placement: .trailingBar) {
            Button(role: .close) {
                withAnimation {
                    isSelecting = false
                    selectedIDs = []
                }
            }
        }
        ToolbarItem(placement: .trailingBar) {
            let selected = visible.filter { selectedIDs.contains($0.id) }
            let allPinned = !selected.isEmpty && selected.allSatisfy(\.isPinned)
            let allArchived = !selected.isEmpty && selected.allSatisfy(\.isArchived)
            Menu("events.more", systemImage: "ellipsis") {
                Button(allPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"), systemImage: allPinned ? "pin.slash" : "pin") {
                    updateSelected(selected) { $0.isPinned = !allPinned }
                }
                Button(allArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                       systemImage: allArchived ? "tray.and.arrow.up" : "archivebox") {
                    updateSelected(selected) { $0.isArchived = !allArchived }
                }
                Divider()
                Button("common.delete", systemImage: "trash", role: .destructive) {
                    isConfirmingDeleteSelected = true
                }
            }
            .disabled(selected.isEmpty)
        }
    }

    /// Changes every selected event at once, then leaves selecting.
    private func updateSelected(_ selected: [EventSnapshot], _ change: (inout EventSnapshot) -> Void) {
        let changed = selected.map { event in
            var event = event
            change(&event)
            event.modifiedAt = .now
            return event
        }
        // An archived event's page closes, as when archiving one by swiping.
        if let open = navigation.selectedEventID, changed.contains(where: { $0.id == open && $0.isArchived && !options.showsArchivedEvents }) {
            navigation.selectedEventID = nil
        }
        withAnimation {
            repository.save(changed)
            isSelecting = false
            selectedIDs = []
        }
    }

    private func delete(_ event: EventSnapshot) {
        if navigation.selectedEventID == event.id { navigation.selectedEventID = nil }
        withAnimation {
            navigation.recentlyDeleted = [event]
            repository.delete(event.id)
        }
    }

    /// Closes the event's page first, then deletes it once it's gone, so the page
    /// never shows an event that no longer exists.
    private func deleteAfterClosing(_ event: EventSnapshot) {
        navigation.selectedEventID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation {
                navigation.recentlyDeleted = [event]
                repository.delete(event.id)
            }
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
        ToolbarItem(placement: .trailingBar) {
            Button("events.select") {
                withAnimation { isSelecting = true }
            }
            // Nothing to pick without events.
            .disabled(repository.events.isEmpty)
        }
        ToolbarSpacer(.fixed, placement: .trailingBar)
        ToolbarItem(placement: .trailingBar) {
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
        ToolbarItem(placement: .trailingBar) {
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
                    // Two equal, large buttons, one above the other: adding comes first.
                    VStack(spacing: 12) {
                        Button(action: onAdd) {
                            PlaceholderActionLabel("common.addEvent", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                        Button(action: onImport) {
                            PlaceholderActionLabel("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.glass)
                    }
                    .controlSize(.large)
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
        #if os(iOS)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        #else
        // ⌫ deletes the event shown, with the same Undo as a swipe.
        .onDeleteCommand {
            guard !isSelecting, let id = selection, let event = events.first(where: { $0.id == id }) else { return }
            onDelete(event)
        }
        #endif
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
                // The tips bring their own background; a row's would box them twice.
                Section {
                    TipView(PinEventTip())
                    TipView(SearchEventsTip())
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .compactSectionSpacing()
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
                    PinnedEventsCarousel(events: sections.pinned, now: now, selection: $selection) { onSave($0.togglingPin()) }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    statusFooter(if: last == .pinned)
                }
                // Close to the tips above and the list below: the cards bring their own room.
                .compactSectionSpacing()
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
        #if os(iOS)
        .listRowSpacing(eventsAreTab ? 12 : nil)
        #endif
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
                    PinnedEventsCarousel(events: sections.pinned, now: now, selection: $selection) { onSave($0.togglingPin()) }
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
                        .accessibilityHidden(true)
                        .font(.title2)
                        .foregroundStyle(isPicked ? Color.accentColor : Color.secondary)
                }
                EventRow(event: event, countdown: event.countdown(at: now))
            }
            .gridCard()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        // What the list's swipe actions offer, as actions VoiceOver can reach on a card too.
        .accessibilityActions {
            if !isSelecting {
                Button("common.edit") { onEdit(event) }
                Button(event.isPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin")) {
                    onSave(event.togglingPin())
                }
                Button(event.isArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive")) {
                    toggleArchive(event)
                }
                Button("common.delete") { deleting = event }
            }
        }
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
                        // Red even with the app's tint, so it never looks like Edit.
                        .tint(.red)
                    Button(event.isArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                           systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
                        toggleArchive(event)
                    }
                    .tint(.indigo)
                    Button("common.edit", systemImage: "pencil") { onEdit(event) }
                        .tint(.gray)
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

/// "“Trip to Lisbon” Deleted · Undo", along the bottom for a few seconds after a delete.
private struct UndoDeleteBanner: View {
    let deleted: [EventSnapshot]
    let onUndo: () -> Void
    let onExpire: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("events.undo", action: onUndo)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: 480)
        // Long enough to notice and reach; a new delete starts the time again.
        .task(id: deleted.map(\.id)) {
            AccessibilityNotification.Announcement(message).post()
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            onExpire()
        }
    }

    private var message: String {
        deleted.count == 1
            ? String(localized: "events.deleted \(deleted[0].title)")
            : String(localized: "events.deletedCount \(deleted.count)")
    }
}
