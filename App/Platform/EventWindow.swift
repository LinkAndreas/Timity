#if os(macOS)
import SwiftUI

/// Windows that show one event each, to keep a countdown in view beside other work.
enum EventWindow {
    static let id = "event"
}

/// An event in a window of its own, editable there; the window closes once the
/// event is deleted, here or anywhere else.
struct EventWindowContent<Detail: View, Editor: View>: View {
    let repository: any EventRepository
    let navigation: EventsNavigation
    let eventID: UUID?
    let detail: (EventSnapshot, _ onEdit: @escaping () -> Void, _ onDelete: @escaping () -> Void) -> Detail
    let editor: (EventSnapshot, _ onSave: @escaping (EventSnapshot) -> Void) -> Editor

    @State private var editing: EventSnapshot?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let event = repository.events.first { $0.id == eventID }
        NavigationStack {
            if let event {
                detail(event, { editing = event }) {
                    dismiss()
                    EventDeletion.delete([event], from: repository, navigation: navigation, undoManager: undoManager)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
        // The Event menu acts on this window's event while it's in front.
        .focusedSceneValue(\.eventMenuActions, event.map { event in
            EventMenuActions(
                events: [event],
                edit: { editing = $0 },
                save: { repository.save($0) },
                delete: { deleted in
                    dismiss()
                    EventDeletion.delete(deleted, from: repository, navigation: navigation, undoManager: undoManager)
                },
                openInWindow: nil
            )
        })
        .onChange(of: event == nil, initial: true) { _, isGone in
            if isGone { dismiss() }
        }
        .sheet(item: $editing) { event in
            editor(event) { repository.save($0) }
        }
    }
}
#endif
