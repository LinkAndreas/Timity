import SwiftUI

/// The search tab: events whose name or notes match what's typed. An event opens
/// right here, as in Music, so Back returns to the results.
struct EventSearchResults<Detail: View, Editor: View>: View {
    let events: [EventSnapshot]
    let query: String
    /// The page for an event, given what to do on Edit and Delete.
    let detail: (EventSnapshot, _ onEdit: @escaping () -> Void, _ onDelete: @escaping () -> Void) -> Detail
    /// The editor for an event, given what to do on Save.
    let editor: (EventSnapshot, _ onSave: @escaping (EventSnapshot) -> Void) -> Editor
    let onSave: (EventSnapshot) -> Void
    let onDelete: (UUID) -> Void

    @State private var path: [UUID] = []
    @State private var editing: EventSnapshot?

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                let matches = matches(at: context.date)
                List(matches) { event in
                    NavigationLink(value: event.id) {
                        EventRow(event: event, countdown: event.countdown(at: context.date))
                    }
                }
                .overlay {
                    if !trimmed.isEmpty, matches.isEmpty {
                        ContentUnavailableView.search(text: trimmed)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { id in
                if let event = events.first(where: { $0.id == id }) {
                    detail(event, { editing = event }, {
                        path.removeAll()
                        onDelete(id)
                    })
                }
            }
        }
        .sheet(item: $editing) { event in
            editor(event, onSave)
        }
    }

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    /// Everything, soonest first, until something is typed.
    private func matches(at now: Date) -> [EventSnapshot] {
        let found = trimmed.isEmpty ? events : events.filter {
            $0.title.localizedStandardContains(trimmed) || $0.notes.localizedStandardContains(trimmed)
        }
        return found.sortedByCountdown(at: now)
    }
}
