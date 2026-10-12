import SwiftData
import SwiftUI

/// Search results for the tab bar's search field: events by name, notes and list.
struct EventSearchTab: View {
    let searchText: String

    @Query private var events: [Event]
    @Environment(\.modelContext) private var modelContext
    @State private var path: [UUID] = []
    @State private var editing: Event?

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let results = results(now: context.date)

                List(results) { event in
                    NavigationLink(value: event.id) {
                        EventRow(event: event, countdown: event.snapshot.countdown(at: context.date))
                    }
                }
                .overlay {
                    if events.isEmpty {
                        ContentUnavailableView("No Events", systemImage: "magnifyingglass", description: Text("Events you add appear here."))
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    EventDetailView(event: event, onEdit: { editing = event }, onDelete: { deleteAfterClosing(event) })
                }
            }
            .sheet(item: $editing) { event in
                EventEditor(event: event) { _ in }
            }
        }
    }

    /// Matching events, soonest first; every event while the field is empty.
    private func results(now: Date) -> [Event] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty
            ? events
            : events.filter {
                $0.title.localizedStandardContains(query)
                    || $0.notes.localizedStandardContains(query)
                    || $0.listName.localizedStandardContains(query)
            }
        let order = matches.map(\.snapshot).sortedByCountdown(at: now).map(\.id)
        return order.compactMap { id in matches.first { $0.id == id } }
    }

    private func deleteAfterClosing(_ event: Event) {
        path.removeAll { $0 == event.id }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation { EventDeletion.delete(event, in: modelContext) }
        }
    }
}
