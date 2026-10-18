#if os(macOS)
import AppKit
import SwiftUI

/// The menu bar extra: the next events and how far away they are, each opening in
/// Timity's window, and a way to add one.
struct MenuBarCountdowns: View {
    let repository: any EventRepository
    let onOpen: (UUID) -> Void
    let onNewEvent: () -> Void

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let now = Date.now
        let upcoming = Self.upcoming(repository.events, at: now)

        if upcoming.isEmpty {
            Text("events.noEventsYet")
        } else {
            ForEach(upcoming.prefix(8)) { event in
                Button {
                    showWindow()
                    onOpen(event.id)
                } label: {
                    Label {
                        Text(verbatim: "\(event.title) · \(CountdownText.relativeDays(event.countdown(at: now)))")
                    } icon: {
                        Image(systemName: event.symbolName)
                    }
                }
            }
        }
        Divider()
        Button("common.newEvent") {
            showWindow()
            onNewEvent()
        }
        .keyboardShortcut("n")
        Button("app.openTimity") { showWindow() }
        Divider()
        Button("app.quitTimity") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Brings Timity's window to the front, opening it again if it was closed.
    private func showWindow() {
        openWindow(id: MainWindow.id)
        NSApp.activate()
    }

    /// Events today and later, pinned ones first, then soonest first.
    static func upcoming(_ events: [EventSnapshot], at now: Date) -> [EventSnapshot] {
        let sorted = events.active.sortedByCountdown(at: now).filter {
            let countdown = $0.countdown(at: now)
            return countdown.direction != .past || countdown.isToday
        }
        return sorted.filter(\.isPinned) + sorted.filter { !$0.isPinned }
    }
}
#endif
