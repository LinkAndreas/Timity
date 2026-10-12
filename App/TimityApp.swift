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
        }
        .modelContainer(TimityStore.container)
        .onChange(of: scenePhase) { _, phase in
            // Day counts and the next occurrences of repeating events change while the app
            // is away, so widgets and reminders catch up whenever it comes and goes.
            guard phase != .inactive else { return }
            refreshDerivedState()
        }
    }

    /// Changes arriving from iCloud update the widgets and this device's reminders.
    private func observeRemoteChanges() async {
        let changes = NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange)
        for await _ in changes {
            refreshDerivedState()
        }
    }

    private func refreshDerivedState() {
        WidgetCenter.shared.reloadAllTimelines()
        TimityShortcuts.updateAppShortcutParameters()
        Task { await ReminderScheduler.reschedule(container: TimityStore.container) }
    }
}
