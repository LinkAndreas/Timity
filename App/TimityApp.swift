import StoreKit
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
                .onChange(of: settings.syncsAfterOnboarding) { composition.iCloudSyncChanged() }
                // Also when the welcome ends with sync off, so the Watch stops waiting.
                .onChange(of: settings.hasCompletedOnboarding) { composition.iCloudSyncChanged() }
                .onChange(of: settings.milestoneAlerts) { _, isOn in composition.milestoneAlertsChanged(to: isOn) }
                .onChange(of: settings.sharesDiagnostics) { _, isOn in composition.sharesDiagnosticsChanged(to: isOn) }
                .onChange(of: settings.birthday) { composition.lifeInWeeksChanged() }
                .onChange(of: settings.lifeExpectancy) { composition.lifeInWeeksChanged() }
                .modifier(ReviewRequest(prompter: composition.reviewPrompter))
                .modifier(WhatsNewPresenter(settings: settings, navigator: composition.navigator))
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
            Button("common.newEvent") {
                navigator.addEvent()
            }
            .keyboardShortcut("n")
            Button("common.importFromContactsAndCalendar") {
                navigator.tab = .events
                navigator.events.isImporting = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandMenu("app.go") {
            Button("common.events") { navigator.tab = .events }
                .keyboardShortcut("1")
            Button("common.calculate") { navigator.tab = .calculators }
                .keyboardShortcut("2")
            Button("common.astronomy") { navigator.tab = .sun }
                .keyboardShortcut("3")
            Button("common.settings") { navigator.tab = .settings }
                .keyboardShortcut(",")
            Divider()
            Button("common.yearInReview") {
                navigator.tab = .events
                navigator.events.isShowingYearInReview = true
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
        }
    }
}

/// Shows Apple's rating prompt once the prompter says it's time, a moment after the
/// good moment itself, so a closing sheet has gone first.
private struct ReviewRequest: ViewModifier {
    let prompter: ReviewPrompter
    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.task(id: prompter.isDue) {
            guard prompter.isDue else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            requestReview()
            prompter.didPrompt()
        }
    }
}

/// Shows What's New once after an update, to people who already used Timity.
private struct WhatsNewPresenter: ViewModifier {
    let settings: AppSettings
    let navigator: Navigator
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .task {
                isShowing = WhatsNew.shouldShow(lastSeen: settings.lastSeenWhatsNew, hasCompletedOnboarding: settings.hasCompletedOnboarding)
            }
            .sheet(isPresented: $isShowing, onDismiss: { settings.lastSeenWhatsNew = WhatsNew.version }) {
                WhatsNewView { navigator.show($0) }
            }
    }
}
