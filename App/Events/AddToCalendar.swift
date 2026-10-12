import EventKit
import EventKitUI
import SwiftUI

/// Calendar's own "New Event" sheet, filled in from a Timity event. It runs outside
/// the app, so adding an event needs no access to the user's calendars.
struct AddToCalendarSheet: UIViewControllerRepresentable {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let calendarEvent = EKEvent(eventStore: store)
        let start = event.snapshot.countdown().target
        calendarEvent.title = event.title
        calendarEvent.isAllDay = event.isAllDay
        calendarEvent.startDate = start
        calendarEvent.endDate = event.isAllDay ? start : start.addingTimeInterval(3600)
        calendarEvent.timeZone = event.timeZone
        calendarEvent.notes = event.notes.isEmpty ? nil : event.notes
        if let rule = Self.recurrenceRule(for: event.recurrenceRule) {
            calendarEvent.recurrenceRules = [rule]
        }

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

    /// Calendar's repeat for a Timity rule, where Calendar can express it.
    private static func recurrenceRule(for rule: RecurrenceRule) -> EKRecurrenceRule? {
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
