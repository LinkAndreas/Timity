import Observation
import SwiftData
import SwiftUI

/// Where the app is, so widgets, notifications and Siri can open an event.
@Observable
final class Navigator {
    static let shared = Navigator()

    enum Tab: Hashable {
        case events, calculators, sun, settings
    }

    var tab: Tab = .events
    var selectedEventID: UUID?
    var isAddingEvent = false
    var isPickingTemplate = false
    var isShowingYearInReview = false
    var isImporting = false
    var calculator: CalculatorsView.Tool?
    /// Values for the next new event, from a received `.timity` file or a typed description.
    var pendingTemplate: EventDraft?

    func showEvent(_ id: UUID) {
        tab = .events
        selectedEventID = id
    }

    /// Handles `timity://event/<id>`, `timity://new` and received `.timity` files.
    func open(_ url: URL) {
        if url.isFileURL {
            openFile(url)
        } else if let id = DeepLink.eventID(in: url) {
            showEvent(id)
        } else if url == DeepLink.newEvent {
            tab = .events
            isAddingEvent = true
        } else if url == DeepLink.lifeInWeeks {
            tab = .calculators
            calculator = .lifeInWeeks
        }
    }

    /// Opens a received event in the editor, ready to be added.
    private func openFile(_ url: URL) {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let file = try EventFile.decode(Data(contentsOf: url))
            pendingTemplate = EventDraft(file)
            tab = .events
            isAddingEvent = true
        } catch {
            logger.error("Couldn't open the event file: \(error)")
        }
    }

    /// Opens a new event if the Control Center control asked for one.
    func openPendingNewEvent() {
        guard SharedSettings.hasPendingNewEvent else { return }
        SharedSettings.hasPendingNewEvent = false
        tab = .events
        isAddingEvent = true
    }
}

/// The tabs; a sidebar on iPad and in wide windows.
struct RootView: View {
    @State private var navigator = Navigator.shared
    @State private var isOnboarding = false
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView(selection: $navigator.tab) {
            Tab("Events", systemImage: "calendar.badge.clock", value: Navigator.Tab.events) {
                EventsView()
            }
            Tab("Calculate", systemImage: "plus.forwardslash.minus", value: Navigator.Tab.calculators) {
                CalculatorsView()
            }
            Tab("Sun", systemImage: "sun.horizon.fill", value: Navigator.Tab.sun) {
                SunView()
            }
            Tab("Settings", systemImage: "gearshape", value: Navigator.Tab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(navigator)
        .onOpenURL { navigator.open($0) }
        // An event chosen in Spotlight.
        .onContinueUserActivity(SpotlightIndex.activityType) { activity in
            if let id = SpotlightIndex.eventID(in: activity) { navigator.showEvent(id) }
        }
        .sheet(isPresented: $isOnboarding) {
            OnboardingView()
        }
        .task {
            // The welcome is for new users; people who already have events skip it.
            guard !settings.hasCompletedOnboarding else { return }
            let count = (try? modelContext.fetchCount(FetchDescriptor<Event>())) ?? 0
            if count > 0 {
                settings.hasCompletedOnboarding = true
            } else {
                isOnboarding = true
            }
        }
    }
}
