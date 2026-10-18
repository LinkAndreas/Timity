import SwiftUI

/// What the Event menu can do with the events picked in the list, shared with the
/// menu bar through the focused scene.
struct EventMenuActions {
    /// The events the menu acts on: the one shown, or all those picked.
    let events: [EventSnapshot]
    let edit: (EventSnapshot) -> Void
    let save: ([EventSnapshot]) -> Void
    let delete: ([EventSnapshot]) -> Void
    /// Opens an event in a window of its own, on the Mac.
    let openInWindow: ((EventSnapshot) -> Void)?

    var single: EventSnapshot? {
        events.count == 1 ? events.first : nil
    }

    var allPinned: Bool {
        !events.isEmpty && events.allSatisfy(\.isPinned)
    }

    var allArchived: Bool {
        !events.isEmpty && events.allSatisfy(\.isArchived)
    }

    func togglePin() {
        let pin = !allPinned
        save(events.map { event in
            var event = event
            event.isPinned = pin
            event.modifiedAt = .now
            return event
        })
    }

    func toggleArchive() {
        let archive = !allArchived
        save(events.map { event in
            var event = event
            event.isArchived = archive
            event.modifiedAt = .now
            return event
        })
    }
}

extension FocusedValues {
    @Entry var eventMenuActions: EventMenuActions?
}

/// The Event menu: edit, pin, archive and delete the events picked in the list,
/// each with its shortcut.
struct EventCommands: Commands {
    @FocusedValue(\.eventMenuActions) private var actions

    var body: some Commands {
        CommandMenu("app.eventMenu") {
            Button("common.edit") {
                if let event = actions?.single { actions?.edit(event) }
            }
            .keyboardShortcut("e")
            .disabled(actions?.single == nil)

            #if os(macOS)
            Button("app.openInNewWindow") {
                if let event = actions?.single { actions?.openInWindow?(event) }
            }
            .keyboardShortcut("o")
            .disabled(actions?.single == nil || actions?.openInWindow == nil)
            #endif

            Divider()

            Button(actions?.allPinned == true ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin")) {
                actions?.togglePin()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(actions?.events.isEmpty ?? true)

            Button(actions?.allArchived == true ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive")) {
                actions?.toggleArchive()
            }
            // As in Mail.
            .keyboardShortcut("a", modifiers: [.command, .control])
            .disabled(actions?.events.isEmpty ?? true)

            Divider()

            Button("common.delete") {
                if let actions { actions.delete(actions.events) }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(actions?.events.isEmpty ?? true)
        }
    }
}

/// The right-click menu for the events clicked in the list: everything for one,
/// what applies to all for several.
struct EventMenuItems: View {
    let actions: EventMenuActions

    var body: some View {
        if let event = actions.single {
            Button("common.edit", systemImage: "pencil") { actions.edit(event) }
            if let openInWindow = actions.openInWindow {
                Button("app.openInNewWindow", systemImage: "macwindow.badge.plus") { openInWindow(event) }
            }
            Divider()
        }
        if !actions.events.isEmpty {
            Button(actions.allPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"),
                   systemImage: actions.allPinned ? "pin.slash" : "pin", action: actions.togglePin)
            Button(actions.allArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                   systemImage: actions.allArchived ? "tray.and.arrow.up" : "archivebox", action: actions.toggleArchive)
        }
        if let event = actions.single {
            ShareLink(item: EventShareText.text(for: event))
            ShareLink(item: EventFileTransfer(event: event), preview: SharePreview(event.title)) {
                Label("common.sendACopy", systemImage: "paperplane")
            }
        }
        if !actions.events.isEmpty {
            Divider()
            Button("common.delete", systemImage: "trash", role: .destructive) { actions.delete(actions.events) }
        }
    }
}

/// Beside the list when several events are picked: how many, and what can be
/// done with them all.
struct PickedEventsSummary: View {
    let actions: EventMenuActions

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "events.selected \(actions.events.count)"), systemImage: "square.stack.3d.up")
        } actions: {
            HStack(spacing: 12) {
                Button(actions.allPinned ? LocalizedStringKey("common.unpin") : LocalizedStringKey("common.pin"),
                       systemImage: actions.allPinned ? "pin.slash" : "pin", action: actions.togglePin)
                Button(actions.allArchived ? LocalizedStringKey("common.unarchive") : LocalizedStringKey("common.archive"),
                       systemImage: actions.allArchived ? "tray.and.arrow.up" : "archivebox", action: actions.toggleArchive)
                Button("common.delete", systemImage: "trash", role: .destructive) { actions.delete(actions.events) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

/// Deleting events so they can come back: from the banner's Undo, and with ⌘Z,
/// which ⇧⌘Z deletes again.
@MainActor
enum EventDeletion {
    static func delete(_ events: [EventSnapshot], from repository: any EventRepository, navigation: EventsNavigation, undoManager: UndoManager?) {
        guard !events.isEmpty else { return }
        navigation.recentlyDeleted = events
        for event in events { repository.delete(event.id) }
        undoManager?.registerUndo(withTarget: navigation) { navigation in
            MainActor.assumeIsolated {
                withAnimation {
                    repository.save(events)
                    navigation.recentlyDeleted = []
                }
                undoManager?.registerUndo(withTarget: navigation) { navigation in
                    MainActor.assumeIsolated {
                        withAnimation { delete(events, from: repository, navigation: navigation, undoManager: undoManager) }
                    }
                }
            }
        }
        undoManager?.setActionName(String(localized: "common.delete"))
    }
}
