import Observation
import SwiftUI

/// Where the app is, so widgets, notifications and Siri can open an event.
@Observable
final class Navigator {
    static let shared = Navigator()

    enum Tab: Hashable {
        case events, calculators, sun, settings, search
    }

    var tab: Tab = .events
    var selectedEventID: UUID?
    var isAddingEvent = false

    func showEvent(_ id: UUID) {
        tab = .events
        selectedEventID = id
    }

    /// Handles `timity://event/<id>` and `timity://new`.
    func open(_ url: URL) {
        if let id = DeepLink.eventID(in: url) {
            showEvent(id)
        } else if url == DeepLink.newEvent {
            tab = .events
            isAddingEvent = true
        }
    }
}

/// The tabs; a sidebar on iPad and in wide windows.
struct RootView: View {
    @State private var navigator = Navigator.shared

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
            Tab(value: Navigator.Tab.search, role: .search) {
                EventSearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(navigator)
        .onOpenURL { navigator.open($0) }
    }
}
