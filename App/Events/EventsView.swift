import SwiftData
import SwiftUI
import WidgetKit

/// The events: a list beside the selected event on iPad, a stack on iPhone.
struct EventsView: View {
    @Environment(Navigator.self) private var navigator
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @State private var editing: Event?
    @State private var isImporting = false
    @State private var searchText = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        @Bindable var navigator = navigator

        NavigationSplitView(columnVisibility: $columnVisibility) {
            EventList(
                events: visibleEvents,
                selection: $navigator.selectedEventID,
                onAdd: { navigator.isAddingEvent = true },
                onImport: { isImporting = true },
                onEdit: { editing = $0 },
                searchText: searchText
            )
            .searchable(text: $searchText, prompt: "Events and Notes")
            .navigationTitle(settings.selectedList ?? String(localized: "Events"))
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
            .toolbar { toolbar }
        } detail: {
            if let event = events.first(where: { $0.id == navigator.selectedEventID }) {
                EventDetailView(event: event, onEdit: { editing = event }, onDelete: { deleteAfterClosing(event) })
                    .id(event.id)
            } else {
                ContentUnavailableView(
                    "Select an Event",
                    systemImage: "calendar",
                    description: Text("Choose an event to see its countdown.")
                )
            }
        }
        .sheet(isPresented: $navigator.isAddingEvent) {
            EventEditor(event: nil, template: navigator.pendingTemplate) { saved in
                navigator.selectedEventID = saved.id
            }
            .onDisappear { navigator.pendingTemplate = nil }
        }
        .sheet(isPresented: $isImporting) {
            ImportView()
        }
        .sheet(item: $editing) { event in
            EventEditor(event: event) { _ in }
        }
    }

    /// Events in the chosen list that match the search; archived ones only when asked for.
    private var visibleEvents: [Event] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return events.filter { event in
            (settings.selectedList == nil || event.listName == settings.selectedList)
                && (settings.showsArchivedEvents || !event.isArchived)
                && (query.isEmpty
                    || event.title.localizedStandardContains(query)
                    || event.notes.localizedStandardContains(query)
                    || event.listName.localizedStandardContains(query))
        }
    }

    /// Closes the event's page first, then deletes it once it's gone, so the page
    /// never shows an event that no longer exists.
    private func deleteAfterClosing(_ event: Event) {
        navigator.selectedEventID = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation { EventDeletion.delete(event, in: modelContext) }
        }
    }

    private var listNames: [String] {
        Set(events.map(\.listName).filter { !$0.isEmpty }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var settings = settings

        ToolbarItem(placement: .primaryAction) {
            Button("Add Event", systemImage: "plus") {
                navigator.isAddingEvent = true
            }
            .keyboardShortcut("n")
        }
        ToolbarItem(placement: .secondaryAction) {
            Menu("Sort and Filter", systemImage: "line.3.horizontal.decrease") {
                Picker("Sort By", selection: $settings.eventSort) {
                    ForEach(AppSettings.EventSort.allCases) { sort in
                        Text(sort.name).tag(sort)
                    }
                }
                if !listNames.isEmpty {
                    Picker("List", selection: $settings.selectedList) {
                        Label("All Events", systemImage: "tray.full").tag(String?.none)
                        ForEach(listNames, id: \.self) { name in
                            Label(name, systemImage: "list.bullet").tag(Optional(name))
                        }
                    }
                }
                Toggle("Show Past Events", isOn: $settings.showsPastEvents)
                Toggle("Show Archived Events", isOn: $settings.showsArchivedEvents)
                Divider()
                Button("Import from Contacts and Calendar", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
            }
        }
    }
}

/// The list of events in sections: pinned, upcoming and past.
struct EventList: View {
    let events: [Event]
    @Binding var selection: UUID?
    let onAdd: () -> Void
    let onImport: () -> Void
    let onEdit: (Event) -> Void
    var searchText = ""

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @State private var deleting: Event?

    var body: some View {
        // Day counts change at midnight, and today's events move to the past during the day.
        TimelineView(.everyMinute) { context in
            let sections = EventSections(events: events, now: context.date, sort: settings.eventSort)

            List(selection: $selection) {
                if !sections.pinned.isEmpty {
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

                if settings.showsPastEvents, !sections.past.isEmpty {
                    Section("Past") {
                        rows(sections.past, now: context.date)
                    }
                }

                if !sections.archived.isEmpty {
                    Section("Archived") {
                        rows(sections.archived, now: context.date)
                    }
                }
            }
            .overlay {
                if events.isEmpty, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if events.isEmpty {
                    ContentUnavailableView {
                        Label("No Events Yet", systemImage: "calendar.badge.plus")
                    } description: {
                        Text("Add birthdays, trips and deadlines to see how long until they come — or since they happened.")
                    } actions: {
                        Button("Add Event", systemImage: "plus", action: onAdd)
                            .buttonStyle(.glassProminent)
                        Button("Import Birthdays and Events", systemImage: "square.and.arrow.down", action: onImport)
                            .buttonStyle(.glass)
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
            Button("Delete “\(event.title)”", role: .destructive) { delete(event) }
        } message: { _ in
            Text("The event is deleted on all your devices.")
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func rows(_ events: [Event], now: Date) -> some View {
        ForEach(events) { event in
            EventRow(event: event, countdown: event.snapshot.countdown(at: now))
                .tag(event.id)
                .swipeActions(edge: .leading) {
                    Button(event.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
                        togglePin(event)
                    }
                    .tint(.orange)
                }
                // A full swipe deletes, as in Mail and Reminders.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) { delete(event) }
                    Button(event.isArchived ? LocalizedStringKey("Unarchive") : LocalizedStringKey("Archive"),
                           systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
                        toggleArchive(event)
                    }
                    .tint(.indigo)
                    Button("Edit", systemImage: "pencil") { onEdit(event) }
                }
                .contextMenu {
                    EventActions(event: event, onEdit: onEdit, onDelete: { deleting = $0 })
                } preview: {
                    EventPreviewCard(event: event, now: now)
                }
        }
    }

    private func toggleArchive(_ event: Event) {
        withAnimation {
            event.isArchived.toggle()
            event.modifiedAt = .now
        }
        if event.isArchived, selection == event.id { selection = nil }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func togglePin(_ event: Event) {
        withAnimation {
            event.isPinned.toggle()
            event.modifiedAt = .now
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func delete(_ event: Event) {
        if selection == event.id { selection = nil }
        withAnimation { EventDeletion.delete(event, in: modelContext) }
    }
}

/// Deletes an event everywhere: the store, which syncs it away, the widgets and reminders.
enum EventDeletion {
    @MainActor
    static func delete(_ event: Event, in context: ModelContext) {
        let id = event.id
        context.delete(event)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            await ReminderScheduler.reschedule(container: context.container)
            await LiveActivityController.end(for: id)
        }
    }
}

/// The actions every event offers in menus.
struct EventActions: View {
    let event: Event
    let onEdit: (Event) -> Void
    let onDelete: (Event) -> Void

    var body: some View {
        Button("Edit", systemImage: "pencil") { onEdit(event) }
        Button(event.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin"), systemImage: event.isPinned ? "pin.slash" : "pin") {
            event.isPinned.toggle()
            event.modifiedAt = .now
            WidgetCenter.shared.reloadAllTimelines()
        }
        Button(event.isArchived ? LocalizedStringKey("Unarchive") : LocalizedStringKey("Archive"),
               systemImage: event.isArchived ? "tray.and.arrow.up" : "archivebox") {
            event.isArchived.toggle()
            event.modifiedAt = .now
            WidgetCenter.shared.reloadAllTimelines()
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
    var pinned: [Event] = []
    var upcoming: [Event] = []
    var past: [Event] = []
    var archived: [Event] = []

    init(events: [Event], now: Date, sort: AppSettings.EventSort) {
        let countdowns = Dictionary(uniqueKeysWithValues: events.map { ($0.persistentModelID, $0.snapshot.countdown(at: now)) })
        func countdown(_ event: Event) -> Countdown { countdowns[event.persistentModelID]! }

        func sorted(_ events: [Event], pastFirstByRecent: Bool) -> [Event] {
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
    static func text(for event: Event, now: Date = .now) -> String {
        let countdown = event.snapshot.countdown(at: now)
        return "\(event.title) — \(CountdownText.relativeDays(countdown)) (\(countdown.targetText))"
    }
}
