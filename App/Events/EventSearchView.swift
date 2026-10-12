import SwiftData
import SwiftUI

/// The search tab: events by name and notes.
struct EventSearchView: View {
    @Query private var events: [Event]
    @State private var searchText = ""
    @State private var editing: Event?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                List {
                    ForEach(results(now: context.date)) { event in
                        NavigationLink(value: event.id) {
                            EventRow(event: event, countdown: event.snapshot.countdown(at: context.date))
                        }
                    }
                }
                .overlay {
                    if !searchText.isEmpty, results(now: context.date).isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if events.isEmpty {
                        ContentUnavailableView("No Events", systemImage: "magnifyingglass", description: Text("Events you add appear here."))
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    EventDetailView(event: event, onEdit: { editing = event })
                }
            }
            .searchable(text: $searchText, prompt: "Events and Notes")
            .sheet(item: $editing) { event in
                EventEditor(event: event) { _ in }
            }
        }
    }

    private func results(now: Date) -> [Event] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty
            ? events
            : events.filter { $0.title.localizedStandardContains(query) || $0.notes.localizedStandardContains(query) }
        let order = matches.map(\.snapshot).sortedByCountdown(at: now).map(\.id)
        return order.compactMap { id in matches.first { $0.id == id } }
    }
}
