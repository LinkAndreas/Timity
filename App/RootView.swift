import SwiftUI
import TipKit

/// Tabs on iPhone and in narrow windows; on iPad, one sidebar for everything,
/// as in Mail and Notes, rather than tabs with sidebars of their own inside.
struct RootView<Events: View, Calculators: View, Calculator: View, Sun: View, Settings: View, NewEvent: View, Onboarding: View>: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Bindable var navigator: Navigator
    /// Whether the welcome has been shown or skipped.
    @Binding var hasCompletedOnboarding: Bool
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
    @SceneStorage("sidebarShowsCalculators") private var showsCalculators = true
    /// The calculator groups open in the sidebar. Kept here, as the sidebar is built
    /// again when the layout changes between the events' three columns and two.
    @State private var openCategories: Set<CalculatorTool.Category> = []
    /// Whether the sidebar shows, shared by the events' three columns and everything else's two,
    /// so it stays as it was when switching between them.
    @State private var showsSidebar = true
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    /// What a calculator or Astronomy hands up for the window's last column.
    @State private var resultColumn = ResultColumnModel()

    init(
        navigator: Navigator,
        hasCompletedOnboarding: Binding<Bool>,
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
            splitLayout
            #else
            // Decided from the size it's given, the first one too.
            GeometryReader { proxy in
                if usesSidebar(in: proxy.size) {
                    splitLayout
                        // The iPhone Duo opened up may count as compact; its columns show anyway.
                        .environment(\.horizontalSizeClass, .regular)
                } else {
                    AppTabLayout(
                        navigator: navigator,
                        events: events,
                        calculators: calculators,
                        sun: sun,
                        settings: settings,
                        newEvent: newEvent
                    )
                    .environment(\.horizontalSizeClass, .compact)
                }
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
            // Everyone goes through the welcome once, Timity 3's users too: it asks what to sync
            // and share, which nothing may decide for them.
            guard !hasCompletedOnboarding else { return }
            isOnboarding = true
        }
    }

    #if os(iOS)
    /// The iPad's sidebar, and the iPhone Duo's opened up, as large as a small iPad either way
    /// round. An iPhone on its side keeps its tabs, as TestFlight does; the largest ones would
    /// otherwise count as wide enough for a sidebar.
    private func usesSidebar(in size: CGSize) -> Bool {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return min(size.width, size.height) >= 600
        }
        return sizeClass == .regular && verticalSizeClass == .regular
    }
    #endif

    // MARK: iPad

    /// The split view, its middle column for the section chosen in the sidebar.
    private var splitLayout: some View {
        AppSplitLayout(
            navigator: navigator,
            resultColumn: resultColumn,
            events: events,
            sidebar: AppSidebar(navigator: navigator, showsCalculators: $showsCalculators, openCategories: $openCategories),
            section: SectionContent(tab: navigator.tab, tool: navigator.calculator, calculator: calculator, sun: sun, settings: settings)
        )
    }
}

/// The sidebar, the section in the middle, and its answer or the event at the end.
private struct AppSplitLayout<Events: View, Sidebar: View, SectionView: View>: View {
    let navigator: Navigator
    /// What a calculator or Astronomy hands up for the window's last column.
    let resultColumn: ResultColumnModel
    /// The events, one column at a time.
    let events: (EventsColumns) -> Events
    let sidebar: Sidebar
    /// Calculate, Astronomy or the iPad's Settings, in the middle column.
    let section: SectionView

    var body: some View {
        // One split view with three columns for every section, on the Mac and the iPad: swapping
        // between a three-column one for the events and a two-column one for the rest rebuilt the
        // window's columns under the same toolbar, which on the Mac laid the sidebar out under the
        // window's buttons. The events list in the middle and the event at the end; a calculator
        // its questions in the middle and its answer at the end; Astronomy its places in the middle
        // and the sky over one at the end.
        NavigationSplitView {
            sidebar
        } content: {
            Group {
                if navigator.tab == .events {
                    events(.list)
                } else {
                    let tab = navigator.tab
                    let tool = navigator.calculator
                    section
                        .environment(\.usesResultColumn, true)
                        .onPreferenceChange(ResultColumnKey.self) { [resultColumn, navigator] content in
                            MainActor.assumeIsolated {
                                // A section on its way out can still hand up its last column after
                                // the next one has; only the one shown counts.
                                guard navigator.tab == tab, navigator.calculator == tool else { return }
                                resultColumn.content = content
                            }
                        }
                        // A section of its own each time, so it hands up its own last column.
                        .id(SectionID(tab: tab, tool: tool))
                }
            }
            #if os(macOS)
            // Again, last: the list's own setting comes before its toolbar and sheets.
            .navigationSplitViewColumnWidth(min: 360, ideal: 400, max: 520)
            #endif
        } detail: {
            if navigator.tab == .events {
                events(.detail)
            } else {
                ResultColumn(model: resultColumn)
            }
        }
        // What the last section or calculator showed there goes with it, rather than staying
        // until the next one hands up its own.
        .onChange(of: navigator.tab) { resultColumn.content = nil }
        .onChange(of: navigator.calculator) { resultColumn.content = nil }
    }

    /// Which section, and which calculator, the middle column shows.
    private struct SectionID: Hashable {
        let tab: Navigator.Tab
        let tool: CalculatorTool?
    }
}

/// Calculate, Astronomy or the iPad's Settings, in the middle column of the one split view.
private struct SectionContent<Calculator: View, Sun: View, Settings: View>: View {
    let tab: Navigator.Tab
    let tool: CalculatorTool?
    let calculator: (CalculatorTool) -> Calculator
    let sun: Sun
    let settings: Settings

    var body: some View {
        switch tab {
        case .calculators:
            NavigationStack { calculator(tool ?? .timeBetween) }
        case .sun:
            sun
        case .settings:
            // The Mac opens its own Settings window instead.
            settings
        case .events:
            // The events have their own columns.
            EmptyView()
        }
    }
}

/// Events, every calculator in its group, Astronomy and, on the iPad, Settings.
private struct AppSidebar: View {
    @Bindable var navigator: Navigator
    @Binding var showsCalculators: Bool
    /// The calculator groups open. Kept above, as the sidebar is built again when the layout changes.
    @Binding var openCategories: Set<CalculatorTool.Category>

    var body: some View {
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
        // Some room between the toolbar and the first row, as in Mail's sidebar.
        .safeAreaPadding(.top, 8)
        // Wide enough for every calculator's and group's name in full, also in French. Last, so the
        // split view sees it: modifiers after it kept it from applying.
        .navigationSplitViewColumnWidth(min: 275, ideal: 285, max: 380)
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
}

// MARK: iPhone

#if os(iOS)
/// A tab per section, and the + that adds an event.
private struct AppTabLayout<Events: View, Calculators: View, Sun: View, Settings: View, NewEvent: View>: View {
    let navigator: Navigator
    let events: (EventsColumns) -> Events
    let calculators: Calculators
    let sun: Sun
    let settings: Settings
    let newEvent: () -> NewEvent

    @State private var isAddingEvent = false

    var body: some View {
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
}
#endif

#if os(macOS)
/// Shows or hides the sidebar, as View > Show Sidebar does. One name for both, as
/// the button isn't drawn again while the sidebar is hidden.
private struct SidebarButton: View {
    @Binding var showsSidebar: Bool

    var body: some View {
        Button {
            // Through the split view's own state, so it lays the sidebar out again under the toolbar.
            withAnimation { showsSidebar.toggle() }
        } label: {
            Label("app.sidebar", systemImage: "sidebar.left")
        }
        .help(Text("app.sidebar"))
    }
}
#endif
