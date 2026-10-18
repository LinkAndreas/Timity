import StoreKit
import SwiftUI

/// The app's one main window, which the menu bar extra brings back when it's closed.
enum MainWindow {
    static let id = "main"
}

@main
struct TimityApp: App {
    @State private var composition = AppComposition()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        let settings = composition.settings
        let supportStore = composition.supportStore

        WindowGroup(id: MainWindow.id) {
            composition.rootView()
                .groupedForms()
                #if os(macOS)
                // Room for the three columns, and for sheets with their buttons.
                .frame(minWidth: 900, minHeight: 680)
                #endif
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.appearance.colorScheme)
                // Finishes purchases that complete outside the purchase flow — Ask to Buy
                // approvals, renewals, purchases on other devices — once per launch.
                .task { supportStore.startObservingTransactions() }
                .task { await supportStore.refreshSupporterStatus() }
                .task { await observeNewEventRequests() }
                #if os(macOS)
                // The Dock forgets a chosen icon when Timity quits.
                .task { try? await Platform.setAppIcon(settings.theme.alternateIconName) }
                #endif
                .onChange(of: settings.syncsAfterOnboarding) { composition.iCloudSyncChanged() }
                // Also when the welcome ends with sync off, so the Watch stops waiting.
                .onChange(of: settings.hasCompletedOnboarding) { composition.iCloudSyncChanged() }
                .onChange(of: settings.milestoneAlerts) { _, isOn in composition.milestoneAlertsChanged(to: isOn) }
                .onChange(of: settings.sharesDiagnostics) { _, isOn in composition.sharesDiagnosticsChanged(to: isOn) }
                .modifier(ReviewRequest(prompter: composition.reviewPrompter))
                .modifier(WhatsNewPresenter(settings: settings, navigator: composition.navigator))
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 740)
        #endif
        .commands { TimityCommands(navigator: composition.navigator) }
        .onChange(of: scenePhase) { _, phase in
            composition.scenePhaseChanged(to: phase)
        }

        #if os(macOS)
        // ⌘, opens the Mac's own Settings window.
        Settings {
            composition.settingsWindow()
                .groupedForms()
                .tint(settings.accentColor.color)
                .preferredColorScheme(settings.appearance.colorScheme)
        }

        // The next countdowns a click away in the menu bar.
        MenuBarExtra {
            composition.menuBarCountdowns()
        } label: {
            Label("common.timity", systemImage: "hourglass")
        }
        #endif
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
            Button("common.importBirthdaysAndEvents") {
                navigator.tab = .events
                navigator.events.isImporting = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        #if os(macOS)
        // The window's way back once it's closed: Timity keeps running for the menu bar extra.
        CommandGroup(before: .windowList) {
            OpenMainWindowButton()
        }
        #endif

        CommandMenu("app.go") {
            Button("common.events") { navigator.tab = .events }
                .keyboardShortcut("1")
            Button("common.calculate") { navigator.tab = .calculators }
                .keyboardShortcut("2")
            Button("common.astronomy") { navigator.tab = .sun }
                .keyboardShortcut("3")
            #if os(iOS)
            // On the Mac, ⌘, opens the Settings window instead.
            Button("common.settings") { navigator.tab = .settings }
                .keyboardShortcut(",")
            #endif
            Divider()
            Button("common.yearInReview") {
                navigator.tab = .events
                navigator.events.isShowingYearInReview = true
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])
        }
    }
}

#if os(macOS)
/// Brings back Timity's window, opening it again if it was closed.
private struct OpenMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("common.timity") { openWindow(id: MainWindow.id) }
            .keyboardShortcut("0")
    }
}
#endif

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
                    .macSheetSize()
            }
    }
}
