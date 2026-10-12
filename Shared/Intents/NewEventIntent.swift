import AppIntents
import Foundation

extension Notification.Name {
    /// Posted when the New Event control runs while Timity is open.
    static let timityNewEventRequested = Notification.Name("de.link.timity.newEventRequested")
}

/// Opens Timity with a new event — the Control Center and Lock Screen control.
struct NewEventIntent: AppIntent {
    static let title: LocalizedStringResource = "New Event"
    static let description = IntentDescription("Opens Timity to add an event.")
    static let openAppWhenRun = true

    @Dependency private var sharedSettings: SharedSettings

    func perform() async throws -> some IntentResult {
        // The control may run in the widget extension; the app picks the flag up when it opens.
        sharedSettings.hasPendingNewEvent = true
        await MainActor.run {
            NotificationCenter.default.post(name: .timityNewEventRequested, object: nil)
        }
        return .result()
    }
}
