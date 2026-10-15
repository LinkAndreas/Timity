import SwiftUI

/// Tabs on iPhone and in narrow windows; on iPad, one sidebar for everything,
/// as in Mail and Notes, rather than tabs with sidebars of their own inside.
struct RootView<Events: View, Calculators: View, Calculator: View, Sun: View, Settings: View, Search: View, NewEvent: View, Onboarding: View>: View {
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
    /// The iPad's Search page: the results for what's typed.
    let search: (String) -> Search
    /// The editor for a new event, which the tab bar's + opens.
    let newEvent: () -> NewEvent
    let onboarding: () -> Onboarding

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isOnboarding = false
    @State private var isAddingEvent = false
    /// What's typed on the iPad's Search page.
    @State private var searchText = ""
    @SceneStorage("sidebarShowsCalculators") private var showsCalculators = true

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
        @ViewBuilder newEvent: @escaping () -> NewEvent,
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
        self.newEvent = newEvent
        self.onboarding = onboarding
    }

    var body: some View {
        Group {
            // An iPhone on its side keeps its tabs, as TestFlight does; the
            // largest ones would otherwise count as wide enough for a sidebar.
            if sizeClass == .regular, verticalSizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
                    .environment(\.horizontalSizeClass, .compact)
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
            // One group that folds away, with a group per topic inside, as in Mail's mailboxes.
            Section(isExpanded: $showsCalculators) {
                ForEach(CalculatorTool.Category.allCases) { category in
                    DisclosureGroup {
                        ForEach(category.tools) { tool in
                            Label(tool.title, systemImage: tool.systemImage)
                                .tag(SidebarItem.calculator(tool))
                        }
                    } label: {
                        Text(category.title)
                    }
                }
            } header: {
                Text("Calculate")
            }
            Section {
                Label("Astronomy", systemImage: "moon.stars.fill")
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
        TabView(selection: tabSelection) {
            Tab("Events", systemImage: "calendar.badge.clock", value: TabItem.tab(.events)) {
                events(.both)
            }
            Tab("Calculate", systemImage: "plusminus.circle", value: TabItem.tab(.calculators)) {
                calculators
            }
            Tab("Astronomy", systemImage: "moon.stars.fill", value: TabItem.tab(.sun)) {
                sun
            }
            Tab("Settings", systemImage: "gearshape", value: TabItem.tab(.settings)) {
                settings
            }
            // The app's main action, apart at the end of the tab bar, as Apple's
            // own apps place it; selecting it opens the editor as a sheet over
            // the open tab, which stays selected.
            Tab("Add Event", systemImage: "plus", value: TabItem.newEvent, role: .prominent) {
                Color.clear
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .toolbarMinimizationBehavior(.onScrollDown, for: .tabBar, .navigationBar)
        .environment(\.eventsAreTab, true)
        .sheet(isPresented: $isAddingEvent) {
            newEvent()
        }
    }

    /// A tab, or the + that adds an event instead of showing a page.
    private enum TabItem: Hashable {
        case tab(Navigator.Tab), newEvent
    }

    /// The selected tab, kept in the navigator. Search lives in the Events list
    /// here, so the iPad's Search page shows as Events.
    private var tabSelection: Binding<TabItem> {
        Binding(
            get: { .tab(navigator.tab == .search ? .events : navigator.tab) },
            set: { item in
                switch item {
                case let .tab(tab): navigator.tab = tab
                case .newEvent: isAddingEvent = true
                }
            }
        )
    }
}
