import CoreData
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct TimityApp: App {
    /// Support the Developer purchases, shared by every window.
    @State private var supportStore = SupportStore(service: StoreKitSupportService())
    @State private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        LegacyImporter.importIfNeeded(into: TimityStore.container)
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supportStore)
                .environment(settings)
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.appearance.colorScheme)
                // Finishes purchases that complete outside the purchase flow — Ask to Buy
                // approvals, renewals, purchases on other devices — once per launch.
                .task { supportStore.startObservingTransactions() }
                .task { await supportStore.refreshSupporterStatus() }
                .task { await observeRemoteChanges() }
                .task { await observeNewEventRequests() }
        }
        .modelContainer(TimityStore.container)
        .commands { TimityCommands() }
        .onChange(of: scenePhase) { _, phase in
            // Day counts and the next occurrences of repeating events change while the app
            // is away, so widgets and reminders catch up whenever it comes and goes.
            guard phase != .inactive else { return }
            refreshDerivedState()
            if phase == .active { Navigator.shared.openPendingNewEvent() }
        }
    }

    /// Changes arriving from iCloud update the widgets and this device's reminders.
    private func observeRemoteChanges() async {
        let changes = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)
        for await _ in changes {
            refreshDerivedState()
        }
    }

    /// The New Event control ran while Timity was already open.
    private func observeNewEventRequests() async {
        for await _ in NotificationCenter.default.notifications(named: .timityNewEventRequested) {
            Navigator.shared.openPendingNewEvent()
        }
    }

    private func refreshDerivedState() {
        WidgetCenter.shared.reloadAllTimelines()
        TimityShortcuts.updateAppShortcutParameters()
        Task {
            await ReminderScheduler.reschedule(container: TimityStore.container)
            await SpotlightIndex.update(container: TimityStore.container)
            let ids = Set(TimityStore.snapshots().map(\.id))
            await LiveActivityController.endFinished(existing: ids)
        }
    }
}

/// The menu bar on iPad and Mac, with keyboard shortcuts for everything common.
struct TimityCommands: Commands {
    private var navigator: Navigator { Navigator.shared }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Event") {
                navigator.tab = .events
                navigator.isAddingEvent = true
            }
            .keyboardShortcut("n")
            Button("New from Template") {
                navigator.tab = .events
                navigator.isPickingTemplate = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Import from Contacts and Calendar") {
                navigator.tab = .events
                navigator.isImporting = true
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
            Button("Search") { navigator.tab = .search }
                .keyboardShortcut("f")
            Button("Year in Review") {
                navigator.tab = .events
                navigator.isShowingYearInReview = true
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
        }
    }
}
