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
        #if os(macOS)
        // One main window on the Mac, as ⌘N adds an event: the menu bar extra, the
        // Window menu and notifications bring back this one rather than opening another.
        Window("common.timity", id: MainWindow.id) {
            MainWindowContent(composition: composition)
                // In full screen the toolbar stays, as in Mail: hidden until the pointer reached the
                // top, it slid in over the sidebar, with the window's buttons on its first row.
                .windowToolbarFullScreenVisibility(.visible)
        }
        .defaultSize(width: 1100, height: 740)
        .keyboardShortcut("0")
        // Links, notifications and files go to this window.
        .handlesExternalEvents(matching: ["*"])
        .commands {
            TimityCommands(navigator: composition.navigator)
            EventCommands()
        }
        .onChange(of: scenePhase) { _, phase in
            composition.scenePhaseChanged(to: phase)
        }
        #else
        WindowGroup(id: MainWindow.id) {
            MainWindowContent(composition: composition)
        }
        .commands { TimityCommands(navigator: composition.navigator) }
        .onChange(of: scenePhase) { _, phase in
            composition.scenePhaseChanged(to: phase)
        }
        #endif

        #if os(macOS)
        // An event in a window of its own, from the Event menu or the list's menu.
        WindowGroup(id: EventWindow.id, for: UUID.self) { $id in
            composition.eventWindow(id)
                .groupedForms()
                .tint(composition.settings.accentColor.color)
                .preferredColorScheme(composition.settings.appearance.colorScheme)
        }
        .defaultSize(width: 440, height: 680)
        // Links always go to the main window.
        .handlesExternalEvents(matching: [])

        // ⌘, opens the Mac's own Settings window.
        Settings {
            composition.settingsWindow()
                .groupedForms()
                .tint(composition.settings.accentColor.color)
                .preferredColorScheme(composition.settings.appearance.colorScheme)
        }

        // The next countdowns a click away in the menu bar.
        MenuBarExtra {
            composition.menuBarCountdowns()
        } label: {
            Label("common.timity", systemImage: "hourglass")
        }
        #endif
    }
}

/// The app in its main window.
private struct MainWindowContent: View {
    let composition: AppComposition

    var body: some View {
        let settings = composition.settings
        let supportStore = composition.supportStore
        return composition.rootView()
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
            #if os(macOS)
            .modifier(MainWindowOpener(navigator: composition.navigator))
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
        // Timity has no help book: the website and a way to write instead.
        CommandGroup(replacing: .help) {
            Link("settings.timityWebsite", destination: URL(string: "https://timity.linkandreas.de")!)
            if let feedback = SupportMail.feedbackURL {
                Link("settings.sendFeedback", destination: feedback)
            }
        }
        #endif

        CommandGroup(after: .textEditing) {
            Button("app.findEvents") {
                navigator.tab = .events
                navigator.events.searchRequests += 1
            }
            .keyboardShortcut("f")
        }

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
/// Lets the navigator bring back the window, e.g. for a notification's event: the
/// action to open it keeps working after the window that gave it has closed.
private struct MainWindowOpener: ViewModifier {
    let navigator: Navigator
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            navigator.showWindow = { [openWindow] in
                openWindow(id: MainWindow.id)
                NSApp.activate()
            }
        }
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
