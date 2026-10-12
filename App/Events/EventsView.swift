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
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        @Bindable var navigator = navigator

        NavigationSplitView(columnVisibility: $columnVisibility) {
            EventList(
                events: events,
                selection: $navigator.selectedEventID,
                onAdd: { navigator.isAddingEvent = true },
                onEdit: { editing = $0 }
            )
            .navigationTitle("Events")
            .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
            .toolbar { toolbar }
        } detail: {
            if let event = events.first(where: { $0.id == navigator.selectedEventID }) {
                EventDetailView(event: event, onEdit: { editing = event })
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
            EventEditor(event: nil) { saved in
                navigator.selectedEventID = saved.id
            }
        }
        .sheet(item: $editing) { event in
            EventEditor(event: event) { _ in }
        }
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
                Toggle("Show Past Events", isOn: $settings.showsPastEvents)
            }
        }
    }
}

/// The list of events in sections: pinned, upcoming and past.
struct EventList: View {
    let events: [Event]
    @Binding var selection: UUID?
    let onAdd: () -> Void
    let onEdit: (Event) -> Void

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
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = event }
                    Button("Edit", systemImage: "pencil") { onEdit(event) }
                }
                .contextMenu {
                    EventActions(event: event, onEdit: onEdit, onDelete: { deleting = $0 })
                } preview: {
                    EventPreviewCard(event: event, now: now)
                }
        }
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
        withAnimation { modelContext.delete(event) }
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ReminderScheduler.reschedule(container: modelContext.container) }
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
        ShareLink(item: EventShareText.text(for: event))
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { onDelete(event) }
    }
}

/// Events split into the list's sections and sorted by the user's choice.
struct EventSections {
    var pinned: [Event] = []
    var upcoming: [Event] = []
    var past: [Event] = []

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

        pinned = sorted(events.filter(\.isPinned), pastFirstByRecent: false)
        let unpinned = events.filter { !$0.isPinned }
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
