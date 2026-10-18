import EventKit
#if os(iOS)
import EventKitUI
#endif
import SwiftUI

#if os(iOS)

/// Calendar's own "New Event" sheet, filled in from a Timity event. It runs outside
/// the app, so adding an event needs no access to the user's calendars.
struct AddToCalendarSheet: UIViewControllerRepresentable {
    let event: EventSnapshot
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let calendarEvent = CalendarEventBuilder.event(for: event, in: store)

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = calendarEvent
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}
#endif

/// A Calendar event for a Timity event: its next occurrence, and its repeat where Calendar can follow it.
enum CalendarEventBuilder {
    static func event(for event: EventSnapshot, in store: EKEventStore) -> EKEvent {
        let calendarEvent = EKEvent(eventStore: store)
        let start = event.countdown().target
        calendarEvent.title = event.title
        calendarEvent.isAllDay = event.isAllDay
        calendarEvent.startDate = start
        calendarEvent.endDate = event.isAllDay ? start : start.addingTimeInterval(3600)
        calendarEvent.timeZone = event.timeZone
        calendarEvent.notes = event.notes.isEmpty ? nil : event.notes
        if let rule = recurrenceRule(for: event.rule) {
            calendarEvent.recurrenceRules = [rule]
        }
        return calendarEvent
    }

    /// Calendar's repeat for a Timity rule, where Calendar can express it.
    static func recurrenceRule(for rule: RecurrenceRule) -> EKRecurrenceRule? {
        // Repeats by other calendars fall on different days each year; Calendar can't follow them.
        guard rule.calendarIdentifier == nil else { return nil }
        let frequency: EKRecurrenceFrequency
        switch rule.frequency {
        case .never: return nil
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        return EKRecurrenceRule(recurrenceWith: frequency, interval: max(1, rule.interval), end: nil)
    }
}

#if os(macOS)
/// On the Mac, which has no Calendar sheet to borrow: the event as it will be added,
/// and a button that adds it to the default calendar.
struct AddToCalendarSheet: View {
    let event: EventSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var failed = false

    var body: some View {
        let countdown = event.countdown()
        VStack(alignment: .leading, spacing: 16) {
            Label("eventDetail.addToCalendar", systemImage: "calendar.badge.plus")
                .font(.headline)
            HStack(spacing: 12) {
                EventBadge(symbolName: event.symbolName, color: event.color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).font(.headline)
                    Text(countdown.targetText).foregroundStyle(.secondary)
                }
            }
            if failed {
                Label("eventDetail.allowCalendarAccess.mac", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            HStack {
                Spacer()
                Button("editor.cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("eventDetail.addToCalendar") { Task { await add() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isAdding)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    /// Adds the event with write-only access, which never lets Timity read the calendar.
    private func add() async {
        isAdding = true
        defer { isAdding = false }
        let store = EKEventStore()
        guard (try? await store.requestWriteOnlyAccessToEvents()) == true else {
            failed = true
            return
        }
        let calendarEvent = CalendarEventBuilder.event(for: event, in: store)
        calendarEvent.calendar = store.defaultCalendarForNewEvents
        do {
            try store.save(calendarEvent, span: .futureEvents)
            dismiss()
        } catch {
            failed = true
        }
    }
}
#endif
