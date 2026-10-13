import SwiftUI

@main
struct TimityApp: App {
    @State private var composition = AppComposition()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        let settings = composition.settings
        let supportStore = composition.supportStore

        WindowGroup {
            composition.rootView()
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.appearance.colorScheme)
                // Finishes purchases that complete outside the purchase flow — Ask to Buy
                // approvals, renewals, purchases on other devices — once per launch.
                .task { supportStore.startObservingTransactions() }
                .task { await supportStore.refreshSupporterStatus() }
                .task { await observeNewEventRequests() }
                .onChange(of: settings.syncsWithICloud) { _, isOn in composition.iCloudSyncChanged(to: isOn) }
                .onChange(of: settings.milestoneAlerts) { _, isOn in composition.milestoneAlertsChanged(to: isOn) }
                .onChange(of: settings.birthday) { composition.lifeInWeeksChanged() }
                .onChange(of: settings.lifeExpectancy) { composition.lifeInWeeksChanged() }
        }
        .commands { TimityCommands(navigator: composition.navigator) }
        .onChange(of: scenePhase) { _, phase in
            composition.scenePhaseChanged(to: phase)
        }
    }

    /// The New Event control ran while Timity was already open.
    private func observeNewEventRequests() async {
        for await _ in NotificationCenter.default.notifications(named: .timityNewEventRequested) {
            composition.openPendingNewEvent()
        }
    }
}

/// The menu bar on iPad and Mac, with keyboard shortcuts for everything common.
struct TimityCommands: Commands {
    let navigator: Navigator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Event") {
                navigator.addEvent()
            }
            .keyboardShortcut("n")
            Button("Import from Contacts and Calendar") {
                navigator.tab = .events
                navigator.events.isImporting = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("Go") {
            Button("Events") { navigator.tab = .events }
                .keyboardShortcut("1")
            Button("Calculate") { navigator.tab = .calculators }
                .keyboardShortcut("2")
            Button("Sun") { navigator.tab = .sun }
                .keyboardShortcut("3")
            Button("Settings") { navigator.tab = .settings }
                .keyboardShortcut(",")
            Divider()
            Button("Year in Review") {
                navigator.tab = .events
                navigator.events.isShowingYearInReview = true
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
        }
    }
}
