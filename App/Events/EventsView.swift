import SwiftUI

/// The events: a list beside the selected event on iPad, a stack on iPhone.
struct EventsView<Detail: View, Editor: View, Importer: View, CloudSync: View>: View {
    /// Builds the page for an event, given what to do on Edit and Delete.
    typealias DetailFactory = (EventSnapshot, _ onEdit: @escaping () -> Void, _ onDelete: @escaping () -> Void) -> Detail
    /// Builds the editor for an event, or for a new one from a template, given what to do on Save.
    typealias EditorFactory = (EventSnapshot?, EventDraft?, _ onSave: @escaping (EventSnapshot) -> Void) -> Editor

    let repository: any EventRepository
    @Bindable var navigation: EventsNavigation
    @Binding var options: AppSettings.EventListOptions
    @Binding var syncsWithICloud: Bool
    /// How iCloud sync is doing, shown at the end of the list.
    let syncState: () -> CloudSyncState
    /// Whose holidays the templates offer.
    let holidayRegion: HolidayRegion?
    let detail: DetailFactory
    let editor: EditorFactory
    let importer: () -> Importer
    /// The iCloud page, opened from the sync status.
    let cloudSync: () -> CloudSync

    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var isConfirmingDeleteSelected = false
    @State private var editing: EventSnapshot?
    @State private var isShowingCloudSync = false
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        let events = repository.events

        NavigationSplitView(columnVisibility: $columnVisibility) {
            EventList(
                events: visibleEvents(events),
                selection: $navigation.selectedEventID,
                isSelecting: isSelecting,
                selectedIDs: $selectedIDs,
                sort: options.sort,
                showsPastEvents: options.showsPastEvents,
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
            // While selecting, the delete button waits at the bottom.
            .safeAreaInset(edge: .bottom) {
                Group {
                    if isSelecting {
                        Button(role: .destructive) {
                            isConfirmingDeleteSelected = true
                        } label: {
                            Label(selectedIDs.isEmpty ? String(localized: "Delete") : String(localized: "Delete (\(selectedIDs.count))"), systemImage: "trash")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .disabled(selectedIDs.isEmpty)
                        .confirmationDialog(
                            selectedIDs.count == 1 ? String(localized: "Delete Event?") : String(localized: "Delete \(selectedIDs.count) Events?"),
                            isPresented: $isConfirmingDeleteSelected,
                            titleVisibility: .visible
                        ) {
                            Button(selectedIDs.count == 1 ? String(localized: "Delete Event") : String(localized: "Delete \(selectedIDs.count) Events"), role: .destructive) {
                                deleteSelected()
                            }
                        } message: {
                            Text("The events are deleted on all your devices.")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(isSelecting ? selectionTitle : options.selectedList ?? String(localized: "Events"))
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
            .toolbar {
                if isSelecting {
                    selectionToolbar(visible: visibleEvents(events))
                } else {
                    toolbar(listNames: events.listNames)
                }
            }
        } detail: {
            if let event = events.first(where: { $0.id == navigation.selectedEventID }) {
                detail(event, { editing = event }, { deleteAfterClosing(event) })
                    .id(event.id)
            } else {
                ContentUnavailableView(
                    "Select an Event",
                    systemImage: "calendar",
                    description: Text("Choose an event to see its countdown.")
                )
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
        .sheet(isPresented: $navigation.isPickingTemplate) {
            TemplatePicker(region: holidayRegion) { draft in
                navigation.pendingTemplate = draft
                // Opened once the picker has gone.
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    navigation.isAddingEvent = true
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
    private func visibleEvents(_ events: [EventSnapshot]) -> [EventSnapshot] {
        events.filter { event in
            (options.selectedList == nil || event.listName == options.selectedList) &&
            (!event.isArchived || options.showsArchivedEvents)
        }
    }

    private var selectionTitle: String {
        selectedIDs.isEmpty ? String(localized: "Select Events") : String(localized: "\(selectedIDs.count) Selected")
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
            Button(selectedIDs.isSuperset(of: all) && !all.isEmpty ? LocalizedStringKey("Deselect All") : LocalizedStringKey("Select All")) {
                selectedIDs = selectedIDs.isSuperset(of: all) ? [] : all
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
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
        ToolbarItem(placement: .primaryAction) {
            Button("Add Event", systemImage: "plus") {
                navigation.isAddingEvent = true
            }
        }
        // Both in sight beside Add, rather than folded into one overflow menu.
        ToolbarItem(placement: .topBarTrailing) {
            Button("Import from Contacts and Calendar", systemImage: "square.and.arrow.down") {
                navigation.isImporting = true
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Sort and Filter", systemImage: "line.3.horizontal.decrease") {
                Button("Select Events", systemImage: "checkmark.circle") {
                    withAnimation { isSelecting = true }
                }
                Divider()
                Picker("Sort By", selection: $options.sort) {
                    ForEach(AppSettings.EventSort.allCases) { sort in
                        Text(sort.name).tag(sort)
                    }
                }
                if !listNames.isEmpty {
                    Picker("List", selection: $options.selectedList) {
                        Label("All Events", systemImage: "tray.full").tag(String?.none)
                        ForEach(listNames, id: \.self) { name in
                            Label(name, systemImage: "list.bullet").tag(Optional(name))
                        }
                    }
                }
                Toggle("Show Past Events", isOn: $options.showsPastEvents)
                Toggle("Show Archived Events", isOn: $options.showsArchivedEvents)
                Divider()
                Button("New from Template", systemImage: "square.grid.2x2") {
                    navigation.isPickingTemplate = true
                }
                Button("Year in Review", systemImage: "chart.bar.xaxis") {
                    navigation.isShowingYearInReview = true
                }
                Divider()
                Toggle(isOn: $syncsWithICloud) {
                    Label("Sync with iCloud", systemImage: "icloud")
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
    let onAdd: () -> Void
    let onImport: () -> Void
    let onEdit: (EventSnapshot) -> Void
    /// Saves a changed event, e.g. pinned or archived.
    let onSave: (EventSnapshot) -> Void
    let onDelete: (EventSnapshot) -> Void
    /// A quiet line at the end of the list, such as how iCloud sync is doing.
    @ViewBuilder let status: () -> Status

    @State private var deleting: EventSnapshot?

    var body: some View {
        // Day counts change at midnight, and today's events move to the past during the day.
        TimelineView(.everyMinute) { context in
            let sections = EventSections(events: events, now: context.date, sort: sort)
            let showsPast = showsPastEvents

            List(selection: listSelection) {
                // While selecting, pinned events are rows like the others, so they can be picked.
                if isSelecting, !sections.pinned.isEmpty {
                    Section("Pinned") {
                        rows(sections.pinned, now: context.date)
                    }
                } else if !sections.pinned.isEmpty {
                    Section {
                        PinnedEventsCarousel(events: sections.pinned, now: context.date, selection: $selection)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if !sections.upcoming.isEmpty {
                    Section("Upcoming") {
                        rows(sections.upcoming, now: context.date)
                    }
                }

                if showsPast, !sections.past.isEmpty {
                    Section("Past") {
                        rows(sections.past, now: context.date)
                    }
                }

                if !sections.archived.isEmpty {
                    Section("Archived") {
                        rows(sections.archived, now: context.date)
                    }
                }

                if !events.isEmpty {
                    Section {
                        status()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .overlay {
                if events.isEmpty {
                    ContentUnavailableView {
                        Label("No Events Yet", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Add birthdays, trips and deadlines to see how long until they come — or since they happened.")
                    } actions: {
                        Button("Add Event", systemImage: "plus", action: onAdd)
                            .buttonStyle(.glassProminent)
                        Button("Import Birthdays and Events", systemImage: "square.and.arrow.down", action: onImport)
                            .buttonStyle(.glass)
                        // On a new device, events may still be on their way from iCloud.
                        status()
                            .padding(.top, 8)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Event?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { event in
            Button("Delete “\(event.title)”", role: .destructive) { onDelete(event) }
        } message: { _ in
            Text("The event is deleted on all your devices.")
        }
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .sensoryFeedback(.selection, trigger: selection)
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
                    Button(event.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
                        withAnimation { onSave(event.togglingPin()) }
                    }
                    .tint(.orange)
                }
                // A full swipe deletes, as in Mail and Reminders.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) { onDelete(event) }
                    Button(event.isArchived ? LocalizedStringKey("Unarchive") : LocalizedStringKey("Archive"),
                           systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
                        toggleArchive(event)
                    }
                    .tint(.indigo)
                    Button("Edit", systemImage: "pencil") { onEdit(event) }
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

extension EventSnapshot {
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
        Button("Edit", systemImage: "pencil") { onEdit(event) }
        Button(event.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
            onSave(event.togglingPin())
        }
        Button(event.isArchived ? LocalizedStringKey("Unarchive") : LocalizedStringKey("Archive"),
               systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
            onSave(event.togglingArchive())
        }
        ShareLink(item: EventShareText.text(for: event))
        ShareLink(item: EventFileTransfer(event: event), preview: SharePreview(event.title)) {
            Label("Send a Copy", systemImage: "paperplane")
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { onDelete(event) }
    }
}

/// Events split into the list's sections and sorted by the user's choice.
struct EventSections {
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

enum EventShareText {
    static func text(for event: EventSnapshot, now: Date = .now) -> String {
        let countdown = event.countdown(at: now)
        return "\(event.title) — \(CountdownText.relativeDays(countdown)) (\(countdown.targetText))"
    }
}
