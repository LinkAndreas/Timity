import AppIntents
import Foundation

/// "How long until my birthday?" — answers with the days to go, in Siri and Shortcuts.
struct CountdownIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Countdown"
    static let description = IntentDescription("Tells you how long until or since an event.")

    @Parameter(title: "Event")
    var event: EventEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the countdown to \(\.$event)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let snapshot = TimityStore.snapshots().first(where: { $0.id == event.id }) else {
            throw IntentError.eventNotFound
        }
        let countdown = snapshot.countdown()
        let phrase = CountdownText.relativeDays(countdown)
        let dialog: IntentDialog = countdown.isToday
            ? "\(snapshot.title) is today."
            : "\(snapshot.title): \(phrase), on \(countdown.targetText)."
        let signedDays = countdown.direction == .past ? -countdown.days : countdown.days
        return .result(value: signedDays, dialog: dialog)
    }

    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case eventNotFound

        var localizedStringResource: LocalizedStringResource {
            "The event couldn't be found."
        }
    }
}

/// Opens an event in Timity.
struct OpenEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Event"
    static let description = IntentDescription("Opens an event in Timity.")
    static let openAppWhenRun = true

    @Parameter(title: "Event")
    var event: EventEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        Navigator.shared.showEvent(event.id)
        return .result()
    }
}

struct TimityShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CountdownIntent(),
            phrases: [
                "How long until \(\.$event) in \(.applicationName)",
                "Countdown to \(\.$event) in \(.applicationName)",
                "\(.applicationName) countdown for \(\.$event)",
            ],
            shortTitle: "Countdown",
            systemImageName: "hourglass"
        )
        AppShortcut(
            intent: OpenEventIntent(),
            phrases: [
                "Open \(\.$event) in \(.applicationName)",
            ],
            shortTitle: "Open Event",
            systemImageName: "calendar"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
