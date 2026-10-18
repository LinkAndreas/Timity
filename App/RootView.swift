import SwiftUI
import TipKit

/// Tabs on iPhone and in narrow windows; on iPad, one sidebar for everything,
/// as in Mail and Notes, rather than tabs with sidebars of their own inside.
struct RootView<Events: View, Calculators: View, Calculator: View, Sun: View, Settings: View, NewEvent: View, Onboarding: View>: View {
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
    /// The editor for a new event, which the tab bar's + opens.
    let newEvent: () -> NewEvent
    let onboarding: () -> Onboarding

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isOnboarding = false
    /// One date row's calendar open at a time, across the app.
    @State private var dateRowFocus = DateRowFocus()
    @State private var isAddingEvent = false
    @SceneStorage("sidebarShowsCalculators") private var showsCalculators = true
    /// The calculator groups open in the sidebar. Kept here, as the sidebar is built
    /// again when the layout changes between the events' three columns and two.
    @State private var openCategories: Set<CalculatorTool.Category> = []
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

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
        self.newEvent = newEvent
        self.onboarding = onboarding
    }

    var body: some View {
        Group {
            #if os(macOS)
            // The Mac's window always has room for the sidebar.
            sidebarLayout
            #else
            // An iPhone on its side keeps its tabs, as TestFlight does; the
            // largest ones would otherwise count as wide enough for a sidebar.
            if sizeClass == .regular, verticalSizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
                    .environment(\.horizontalSizeClass, .compact)
            }
            #endif
        }
        .environment(dateRowFocus)
        #if os(macOS)
        // Settings live in their own window on the Mac; a link there opens it.
        .onChange(of: navigator.tab, initial: true) { _, tab in
            guard tab == .settings else { return }
            navigator.tab = .events
            openSettings()
        }
        #endif
        // Every tip in place looks alike, on a card like the list's rows, so it
        // stands out from the background.
        .tipViewStyle(TimityTipStyle())
        .tipBackground(Color(uiColor: .secondarySystemGroupedBackground))
        .tipCornerRadius(24)
        .onOpenURL(perform: onOpenURL)
        .onContinueUserActivity(searchActivityType, perform: onContinueSearch)
        // Full screen, with nothing to swipe away; should it close anyhow before
        // Start Counting, it comes straight back.
        .fullScreen(isPresented: $isOnboarding, onDismiss: {
            if !hasCompletedOnboarding { isOnboarding = true }
        }) {
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
                Group {
                    switch navigator.tab {
                    case .calculators:
                        NavigationStack { calculator(navigator.calculator ?? .timeBetween) }
                    case .sun:
                        sun
                    case .settings:
                        settings
                    case .events:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Label("common.events", systemImage: "calendar.badge.clock")
                .tag(SidebarItem.events)
            // One group that folds away, with a group per topic inside, as in Mail's mailboxes.
            Section(isExpanded: $showsCalculators) {
                ForEach(CalculatorTool.Category.allCases) { category in
                    DisclosureGroup(isExpanded: categoryBinding(category)) {
                        ForEach(category.tools) { tool in
                            Label(tool.title, systemImage: tool.systemImage)
                                .tag(SidebarItem.calculator(tool))
                        }
                    } label: {
                        Text(category.title)
                    }
                }
            } header: {
                Text("common.calculate")
            }
            Section {
                Label("common.astronomy", systemImage: "moon.stars.fill")
                    .tag(SidebarItem.sun)
                #if os(iOS)
                // The Mac has its own Settings window.
                Label("common.settings", systemImage: "gearshape")
                    .tag(SidebarItem.settings)
                #endif
            }
        }
        .navigationTitle("common.timity")
        // A calculator chosen from a menu, a link or What's New shows in its open group.
        .onChange(of: navigator.calculator, initial: true) { _, tool in
            if let tool { openCategories.insert(tool.category) }
        }
        #if os(macOS)
        // Wide enough for the calculator groups' names.
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        // The sidebar button beside the window's buttons, as in Mail and Notes, rather
        // than at the sidebar's far edge.
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            // Stays in the toolbar while the sidebar is hidden, so it shows it again.
            ToolbarItem(placement: .navigation) {
                SidebarButton()
            }
        }
        #endif
    }

    /// Whether a calculator group is open.
    private func categoryBinding(_ category: CalculatorTool.Category) -> Binding<Bool> {
        Binding(
            get: { openCategories.contains(category) },
            set: { isOpen in
                if isOpen { openCategories.insert(category) } else { openCategories.remove(category) }
            }
        )
    }

    private enum SidebarItem: Hashable {
        case events, calculator(CalculatorTool), sun, settings
    }

    /// The sidebar's row, kept in the navigator, so links and menus still lead
    /// to the right place.
    private var sidebarSelection: Binding<SidebarItem?> {
        Binding(
            get: {
                switch navigator.tab {
                case .events: .events
                case .calculators: .calculator(navigator.calculator ?? .timeBetween)
                case .sun: .sun
                case .settings: .settings
                }
            },
            set: { item in
                switch item {
                case .events: navigator.tab = .events
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

    #if os(iOS)
    private var tabLayout: some View {
        TabView(selection: tabSelection) {
            Tab("common.events", systemImage: "calendar.badge.clock", value: TabItem.tab(.events)) {
                events(.both)
            }
            Tab("common.calculate", systemImage: "plusminus.circle", value: TabItem.tab(.calculators)) {
                calculators
            }
            Tab("common.astronomy", systemImage: "moon.stars.fill", value: TabItem.tab(.sun)) {
                sun
            }
            Tab("common.settings", systemImage: "gearshape", value: TabItem.tab(.settings)) {
                settings
            }
            // The app's main action, apart at the end of the tab bar, as Apple's
            // own apps place it; selecting it opens the editor as a sheet over
            // the open tab, which stays selected.
            Tab("common.addEvent", systemImage: "plus", value: TabItem.newEvent, role: .prominent) {
                Color.clear
            }
        }
        // Room between the end of every page and the floating tab bar, so the
        // last footer doesn't end right against it.
        .contentMargins(.bottom, 24, for: .scrollContent)
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

    /// The selected tab, kept in the navigator.
    private var tabSelection: Binding<TabItem> {
        Binding(
            get: { .tab(navigator.tab) },
            set: { item in
                switch item {
                case let .tab(tab): navigator.tab = tab
                case .newEvent: isAddingEvent = true
                }
            }
        )
    }
    #endif
}

#if os(macOS)
/// Shows or hides the sidebar, as View > Show Sidebar does. One name for both, as
/// the button isn't drawn again while the sidebar is hidden.
private struct SidebarButton: View {
    var body: some View {
        Button {
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Label("app.sidebar", systemImage: "sidebar.left")
        }
        .help(Text("app.sidebar"))
    }
}
#endif
