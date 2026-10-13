import SwiftUI

/// The tabs; a sidebar on iPad and in wide windows.
struct RootView<Events: View, Calculators: View, Sun: View, Settings: View, Search: View, Onboarding: View>: View {
    @Bindable var navigator: Navigator
    /// Whether the welcome has been shown or skipped.
    @Binding var hasCompletedOnboarding: Bool
    /// Whether there are events; people who already have some skip the welcome.
    let hasEvents: () -> Bool
    /// The user activity a system search result opens the app with.
    let searchActivityType: String
    let onOpenURL: (URL) -> Void
    let onContinueSearch: (NSUserActivity) -> Void
    let events: Events
    let calculators: Calculators
    let sun: Sun
    let settings: Settings
    /// The search tab's results for what's typed.
    let search: (String) -> Search
    let onboarding: () -> Onboarding

    @State private var isOnboarding = false
    @State private var searchText = ""

    init(
        navigator: Navigator,
        hasCompletedOnboarding: Binding<Bool>,
        hasEvents: @escaping () -> Bool,
        searchActivityType: String,
        onOpenURL: @escaping (URL) -> Void,
        onContinueSearch: @escaping (NSUserActivity) -> Void,
        @ViewBuilder events: () -> Events,
        @ViewBuilder calculators: () -> Calculators,
        @ViewBuilder sun: () -> Sun,
        @ViewBuilder settings: () -> Settings,
        @ViewBuilder search: @escaping (String) -> Search,
        @ViewBuilder onboarding: @escaping () -> Onboarding
    ) {
        self.navigator = navigator
        _hasCompletedOnboarding = hasCompletedOnboarding
        self.hasEvents = hasEvents
        self.searchActivityType = searchActivityType
        self.onOpenURL = onOpenURL
        self.onContinueSearch = onContinueSearch
        self.events = events()
        self.calculators = calculators()
        self.sun = sun()
        self.settings = settings()
        self.search = search
        self.onboarding = onboarding
    }

    var body: some View {
        TabView(selection: $navigator.tab) {
            Tab("Events", systemImage: "calendar.badge.clock", value: Navigator.Tab.events) {
                events
            }
            Tab("Calculate", systemImage: "plusminus.circle", value: Navigator.Tab.calculators) {
                calculators
            }
            Tab("Sun", systemImage: "sun.horizon.fill", value: Navigator.Tab.sun) {
                sun
            }
            Tab("Settings", systemImage: "gearshape", value: Navigator.Tab.settings) {
                settings
            }
            // Apple's search for tab-based apps: a button at the end of the tab
            // bar that turns into a search field at the bottom, as in Music.
            Tab(value: Navigator.Tab.search, role: .search) {
                search(searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search Events/Notes")
        .tabViewSearchActivation(.searchTabSelection)
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onOpenURL(perform: onOpenURL)
        .onContinueUserActivity(searchActivityType, perform: onContinueSearch)
        .sheet(isPresented: $isOnboarding) {
            onboarding()
        }
        .task {
            // The welcome is for new users; people who already have events skip it.
            guard !hasCompletedOnboarding else { return }
            if hasEvents() {
                hasCompletedOnboarding = true
            } else {
                isOnboarding = true
            }
        }
    }
}
