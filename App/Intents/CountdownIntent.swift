import AppIntents
import Foundation

/// "How long until my birthday?" — answers with the days to go, in Siri and Shortcuts.
struct CountdownIntent: AppIntent {
    static let title: LocalizedStringResource = "intents.getCountdown"
    static let description = IntentDescription("intents.tellsYouHowLongUntil")

    @Parameter(title: "common.event")
    var event: EventEntity

    @Dependency private var reader: any EventReader

    static var parameterSummary: some ParameterSummary {
        Summary("Get the countdown to \(\.$event)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let snapshot = reader.fetchEvents().first(where: { $0.id == event.id }) else {
            throw IntentError.eventNotFound
        }
        let countdown = snapshot.countdown()
        let phrase = CountdownText.relativeDays(countdown)
        let dialog: IntentDialog = countdown.isToday
            ? "intents.isToday \(snapshot.title)"
            : "intents.on \(snapshot.title) \(phrase) \(countdown.targetText)"
        let signedDays = countdown.direction == .past ? -countdown.days : countdown.days
        return .result(value: signedDays, dialog: dialog)
    }

    nonisolated enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case eventNotFound

        var localizedStringResource: LocalizedStringResource {
            "intents.theEventCouldntBeFound"
        }
    }
}

/// Opens an event in Timity.
struct OpenEventIntent: AppIntent {
    static let title: LocalizedStringResource = "intents.openEvent"
    static let description = IntentDescription("intents.opensAnEventInTimity")
    static let openAppWhenRun = true

    @Parameter(title: "common.event")
    var event: EventEntity

    @Dependency private var navigator: Navigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.showEvent(event.id)
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
            shortTitle: "common.countdown",
            systemImageName: "hourglass"
        )
        AppShortcut(
            intent: CreateEventIntent(),
            phrases: [
                "Add a countdown in \(.applicationName)",
                "Add an event to \(.applicationName)",
            ],
            shortTitle: "intents.addCountdown",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: DaysBetweenIntent(),
            phrases: [
                "Count days with \(.applicationName)",
            ],
            shortTitle: "intents.daysBetween",
            systemImageName: "arrow.left.and.right"
        )
        AppShortcut(
            intent: OpenEventIntent(),
            phrases: [
                "Open \(\.$event) in \(.applicationName)",
            ],
            shortTitle: "intents.openEvent",
            systemImageName: "calendar"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .orange
}
