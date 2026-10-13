import SwiftUI

/// Tabs on iPhone and in narrow windows; on iPad, one sidebar for everything,
/// as in Mail and Notes, rather than tabs with sidebars of their own inside.
struct RootView<Events: View, Calculators: View, Calculator: View, Sun: View, Settings: View, Search: View, Onboarding: View>: View {
    @Bindable var navigator: Navigator
    /// Whether the welcome has been shown or skipped.
    @Binding var hasCompletedOnboarding: Bool
    /// Whether there are events; people who already have some skip the welcome.
    let hasEvents: () -> Bool
    /// The user activity a system search result opens the app with.
    let searchActivityType: String
    let onOpenURL: (URL) -> Void
    let onContinueSearch: (NSUserActivity) -> Void
    /// The events, or one column of them in the iPad layout.
    let events: (EventsColumns) -> Events
    let calculators: Calculators
    /// One calculator, for the iPad sidebar, which lists them all.
    let calculator: (CalculatorTool) -> Calculator
    let sun: Sun
    let settings: Settings
    /// The search tab's results for what's typed.
    let search: (String) -> Search
    let onboarding: () -> Onboarding

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isOnboarding = false
    @State private var searchText = ""

    init(
        navigator: Navigator,
        hasCompletedOnboarding: Binding<Bool>,
        hasEvents: @escaping () -> Bool,
        searchActivityType: String,
        onOpenURL: @escaping (URL) -> Void,
        onContinueSearch: @escaping (NSUserActivity) -> Void,
        @ViewBuilder events: @escaping (EventsColumns) -> Events,
        @ViewBuilder calculators: () -> Calculators,
        @ViewBuilder calculator: @escaping (CalculatorTool) -> Calculator,
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
        self.events = events
        self.calculators = calculators()
        self.calculator = calculator
        self.sun = sun()
        self.settings = settings()
        self.search = search
        self.onboarding = onboarding
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
            }
        }
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

    // MARK: iPad

    /// Events in three columns, sidebar, list and event; everything else beside
    /// the sidebar.
    @ViewBuilder
    private var sidebarLayout: some View {
        if navigator.tab == .events {
            NavigationSplitView {
                sidebar
            } content: {
                events(.list)
            } detail: {
                events(.detail)
            }
        } else {
            NavigationSplitView {
                sidebar
            } detail: {
                switch navigator.tab {
                case .calculators:
                    NavigationStack { calculator(navigator.calculator ?? .timeBetween) }
                case .sun:
                    sun
                case .settings:
                    settings
                case .search:
                    search(searchText)
                        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Events/Notes")
                case .events:
                    EmptyView()
                }
            }
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Label("Events", systemImage: "calendar.badge.clock")
                .tag(SidebarItem.events)
            Label("Search", systemImage: "magnifyingglass")
                .tag(SidebarItem.search)
            ForEach(CalculatorTool.Category.allCases) { category in
                Section(category.title) {
                    ForEach(category.tools) { tool in
                        Label(tool.title, systemImage: tool.systemImage)
                            .tag(SidebarItem.calculator(tool))
                    }
                }
            }
            Section {
                Label("Sun", systemImage: "sun.horizon.fill")
                    .tag(SidebarItem.sun)
                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
            }
        }
        .navigationTitle("Timity")
    }

    private enum SidebarItem: Hashable {
        case events, search, calculator(CalculatorTool), sun, settings
    }

    /// The sidebar's row, kept in the navigator, so links and menus still lead
    /// to the right place.
    private var sidebarSelection: Binding<SidebarItem?> {
        Binding(
            get: {
                switch navigator.tab {
                case .events: .events
                case .search: .search
                case .calculators: .calculator(navigator.calculator ?? .timeBetween)
                case .sun: .sun
                case .settings: .settings
                }
            },
            set: { item in
                switch item {
                case .events: navigator.tab = .events
                case .search: navigator.tab = .search
                case let .calculator(tool):
                    navigator.calculator = tool
                    navigator.tab = .calculators
                case .sun: navigator.tab = .sun
                case .settings: navigator.tab = .settings
                case nil: break
                }
            }
        )
    }

    // MARK: iPhone

    private var tabLayout: some View {
        TabView(selection: $navigator.tab) {
            Tab("Events", systemImage: "calendar.badge.clock", value: Navigator.Tab.events) {
                events(.both)
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
                // On the tab itself, so other tabs don't get a search field too.
                search(searchText)
                    .searchable(text: $searchText, prompt: "Search Events/Notes")
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
