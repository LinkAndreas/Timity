import AppIntents
import SwiftUI
import UIKit
import UserNotifications

/// The app's composition root: the one place that knows which framework does
/// what. It holds only what lives as long as the app; everything else is built
/// where it's needed — stateless adapters on the spot, a screen's models with
/// `WithState`, so they live and die with the screen.
@MainActor
final class AppComposition {
    let settings: AppSettings
    let navigator: Navigator
    /// App-wide, as purchases that complete outside the Support screen are finished at launch.
    let supportStore = SupportStore(service: AppComposition.supportService())
    /// Asks for a rating with Apple's prompt once someone clearly enjoys Timity.
    let reviewPrompter: ReviewPrompter

    private let sharedSettings: SharedSettings
    private let database: EventDatabase
    private let repository: SwiftDataEventRepository
    private let cloudSync: CloudKitSyncMonitor
    private let cloudSyncRepair: CloudSyncRepair
    private let watchSyncSetting: any SyncSettingSharing = WatchConnectivitySyncSettingSharer()
    private let coordinator: EventChangeCoordinator
    private let notificationRouter: NotificationTapRouter

    init() {
        let defaults = UserDefaults.standard
        let sharedSettings = SharedSettings(store: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)
        let settings = AppSettings(defaults: defaults, shared: sharedSettings)
        let database = EventDatabase(syncsWithICloud: settings.syncsAfterOnboarding)
        let repository = SwiftDataEventRepository(database: database)
        let navigator = Navigator()

        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        let cloudSyncRepair = CloudSyncRepair(
            database: database,
            repository: repository,
            remover: CloudKitEventsRemover(containerIdentifier: AppGroup.cloudContainer),
            pendingEventsURL: .applicationSupportDirectory.appending(path: "PendingEvents.json")
        )
        cloudSyncRepair.restorePendingEvents()
        LegacyImporter.importIfNeeded(into: repository, defaults: defaults)
        if sharedSettings.place == nil {
            sharedSettings.place = LegacyImporter.place(in: defaults)
        }

        self.sharedSettings = sharedSettings
        self.settings = settings
        reviewPrompter = ReviewPrompter(
            store: defaults,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            isSetUp: { [settings] in settings.hasCompletedOnboarding }
        )
        self.database = database
        self.cloudSyncRepair = cloudSyncRepair
        self.repository = repository
        cloudSync = CloudKitSyncMonitor(isEnabled: settings.syncsAfterOnboarding, storeSyncs: database.syncsWithICloud, containerIdentifier: AppGroup.cloudContainer)
        self.navigator = navigator
        // Day counts, reminders and search results follow the events, wherever they changed.
        coordinator = EventChangeCoordinator(repository: repository, handlers: [
            { _ in
                WidgetKitRefresher().reloadAll()
                TimityShortcuts.updateAppShortcutParameters()
            },
            { events in
                await UserNotificationReminderScheduler().schedule(
                    ReminderPlanner.reminders(for: events, includingMilestones: settings.milestoneAlerts)
                )
            },
            { events in await SpotlightSearchIndex().update(events) },
            { events in await ActivityKitLiveActivities().endFinished(existing: Set(events.map(\.id)), now: .now) },
        ])
        notificationRouter = NotificationTapRouter { navigator.showEvent($0) }
        UNUserNotificationCenter.current().delegate = notificationRouter

        IntentDependencies.register(
            repository: repository,
            reader: SwiftDataEventReader(database: database),
            widgets: WidgetKitRefresher(),
            sharedSettings: sharedSettings
        )
        AppDependencyManager.shared.add(dependency: navigator)
        coordinator.start()
        cloudSync.start()
        watchSyncSetting.share(syncsWithICloud: settings.syncsAfterOnboarding, isSetUp: settings.hasCompletedOnboarding)
        #if DEBUG
        Self.prepareCloudKitSchemaIfAsked()
        ScreenshotSamples.addIfAsked(to: repository)
        #endif
    }

    private static func supportService() -> SupportStoreService {
        #if DEBUG
        // App Store review screenshots of the Support screen, without the App Store.
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotSupportOffers") { return PreviewSupportService() }
        #endif
        return StoreKitSupportService()
    }

    #if DEBUG
    /// Launched with `-PrepareCloudKitSchema`, creates the CloudKit schema in the
    /// development environment and prints the outcome — for preparing it from a
    /// connected device without tapping through the app.
    private static func prepareCloudKitSchemaIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains("-PrepareCloudKitSchema") else { return }
        Task.detached {
            do {
                try EventDatabase.initializeCloudKitSchema()
                print("CloudKit schema: done")
            } catch {
                var current: NSError? = error as NSError
                while let error = current {
                    print("CloudKit schema: \(error.domain) \(error.code): \(error.localizedDescription) \(error.userInfo)")
                    current = error.userInfo[NSUnderlyingErrorKey] as? NSError
                }
            }
        }
    }
    #endif

    // MARK: Lifecycle

    /// Catches up when the app comes and goes: day counts and the next occurrences
    /// of repeating events change while it's away, and widgets may have changed events.
    func scenePhaseChanged(to phase: ScenePhase) {
        guard phase != .inactive else { return }
        repository.reload()
        coordinator.refresh()
        if phase == .active {
            reviewPrompter.recordActiveDay()
            openPendingNewEvent()
            Task { await cloudSync.checkAccount() }
        }
    }

    /// After a repair, the status starts over from what the store now does.
    private func repaired() {
        cloudSync.setEnabled(settings.syncsAfterOnboarding, storeSyncs: database.syncsWithICloud)
    }

    /// Opens the store again with or without iCloud, as the sync setting and the
    /// welcome now call for; the events on this device stay.
    func iCloudSyncChanged() {
        let isOn = settings.syncsAfterOnboarding
        // What this iPhone really does, so a Watch doesn't sync before the welcome has asked.
        watchSyncSetting.share(syncsWithICloud: isOn, isSetUp: settings.hasCompletedOnboarding)
        guard isOn != database.syncsWithICloud || isOn != cloudSync.state.isEnabled else { return }
        database.reopen(syncsWithICloud: isOn)
        cloudSync.setEnabled(isOn, storeSyncs: database.syncsWithICloud)
        repository.reload()
    }

    /// Opens a new event if the Control Center control asked for one.
    func openPendingNewEvent() {
        guard sharedSettings.hasPendingNewEvent else { return }
        sharedSettings.hasPendingNewEvent = false
        navigator.addEvent()
    }

    func milestoneAlertsChanged(to isOn: Bool) {
        Task {
            if isOn { await UserNotificationReminderScheduler().requestAuthorization() }
            coordinator.refresh()
        }
    }

    func lifeInWeeksChanged() {
        WidgetKitRefresher().reload(.lifeInWeeks)
    }

    // MARK: Screens

    func rootView() -> some View {
        RootView(
            navigator: navigator,
            hasCompletedOnboarding: Bindable(settings).hasCompletedOnboarding,
            hasEvents: { [repository] in !repository.events.isEmpty },
            searchActivityType: SpotlightSearchIndex().activityType,
            onOpenURL: { [self] in open($0) },
            onContinueSearch: { [navigator] activity in
                if let id = SpotlightSearchIndex().eventID(in: activity) { navigator.showEvent(id) }
            },
            events: { [self] columns in eventsView(columns: columns) },
            calculators: {
                CalculatorsView(selection: Bindable(navigator).calculator) { [self] tool in calculator(tool) }
            },
            calculator: { [self] tool in calculator(tool) },
            sun: { sunView() },
            settings: { settingsView() },
            search: { [self] query in
                EventSearchResults(
                    events: repository.events,
                    query: query,
                    detail: { [self] event, onEdit, onDelete in eventDetail(event, onEdit: onEdit, onDelete: onDelete) },
                    editor: { [self] event, onSave in editor(event: event, template: nil, onSave: onSave) },
                    onSave: { [repository] in repository.save($0) },
                    onDelete: { [repository] in repository.delete($0) }
                )
            },
            newEvent: { [self] in
                editor(event: nil, template: nil) { [repository, navigator] saved in
                    repository.save(saved)
                    navigator.showEvent(saved.id)
                }
            },
            onboarding: { [self] in onboardingView() }
        )
    }

    private func eventsView(columns: EventsColumns) -> some View {
        EventsView(
            repository: repository,
            navigation: navigator.events,
            options: Bindable(settings).eventList,
            syncState: { [cloudSync] in cloudSync.state },
            detail: { [self] event, onEdit, onDelete in eventDetail(event, onEdit: onEdit, onDelete: onDelete) },
            editor: { [self] event, template, onSave in editor(event: event, template: template, onSave: onSave) },
            importer: { [self] in importView() },
            cloudSync: { [self] in cloudSyncView() },
            columns: columns
        )
    }

    private func eventDetail(_ event: EventSnapshot, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        EventDetailView(
            event: event,
            showsWeeks: settings.showsWeeks,
            showsSeconds: settings.showsSeconds,
            liveActivities: ActivityKitLiveActivities(),
            onEdit: onEdit,
            onSave: { [repository] in repository.save($0) },
            onDelete: onDelete
        )
        // Opening an event on its day is one of the good moments.
        .onAppear { [reviewPrompter] in
            if event.countdown().isToday { reviewPrompter.recordEventDay() }
        }
    }

    private func editor(event: EventSnapshot?, template: EventDraft?, onSave: @escaping (EventSnapshot) -> Void) -> some View {
        EventEditor(
            event: event,
            template: template,
            templates: EventTemplate.allCases.compactMap { template in
                template.draft(region: settings.holidayRegion).map { (template, $0) }
            },
            listNames: repository.events.listNames,
            requestReminderPermission: { await UserNotificationReminderScheduler().requestAuthorization() },
            parseDescription: { await EventTextParser.parse($0) },
            onSave: { [reviewPrompter] saved in
                onSave(saved)
                // A new event is one of the good moments; edits aren't.
                if event == nil { reviewPrompter.recordHappyMoment() }
            }
        )
    }

    private func importView() -> some View {
        ImportView(
            existingEvents: repository.events,
            defaultHolidayRegion: settings.holidayRegion,
            loadContacts: { try await ContactsImport.candidates() },
            loadCalendar: { try await CalendarImport.candidates() },
            onImport: { [repository] in repository.save($0) }
        )
    }

    /// The Sun tab, finding the place with a location manager that exists only while the tab does.
    private func sunView() -> some View {
        WithState { [sharedSettings] in
            SunPlaceModel(
                place: sharedSettings.place,
                choices: sharedSettings.sunChoices,
                locator: GeocodingPlaceLocator(CoreLocationPlaceLocator()),
                onChoices: { sharedSettings.sunChoices = $0 }
            ) { place in
                sharedSettings.place = place
                WidgetKitRefresher().reload(.sun)
            }
        } content: { place in
            SunView(location: place, searchPlaces: { await MapKitPlaceSearch().places(matching: $0) })
        }
    }

    @ViewBuilder
    private func calculator(_ tool: CalculatorTool) -> some View {
        let settings = Bindable(settings)
        let saveAndShow: (EventSnapshot) -> Void = { [repository, navigator] event in
            repository.save(event)
            navigator.showEvent(event.id)
        }
        switch tool {
        case .timeBetween:
            TimeBetweenView(showsWeeks: self.settings.showsWeeks)
        case .addSubtract:
            AddSubtractView(onSaveAsEvent: saveAndShow)
        case .workingDays:
            WorkingDaysView(holidayRegion: settings.holidayRegion)
        case .bridgeDays:
            BridgeDaysView(holidayRegion: settings.holidayRegion)
        case .flight:
            FlightArrivalView()
        case .milestones:
            MilestonesView(birthday: self.settings.birthday, onSaveAsEvent: saveAndShow)
        case .weekNumbers:
            WeekNumbersView()
        case .calendarConverter:
            CalendarConverterView(onSaveAsEvent: saveAndShow)
        case .hours:
            HoursView()
        case .shift:
            ShiftView()
        case .timeZones:
            TimeZonePlannerView()
        case .sleep:
            SleepView(bedtimeReminder: UserNotificationBedtimeReminder())
        case .age:
            AgeView(birthday: settings.birthday)
        case .lifeInWeeks:
            LifeInWeeksView(birthday: settings.birthday, lifeExpectancy: settings.lifeExpectancy, color: self.settings.accentColor)
        }
    }

    private func settingsView() -> some View {
        let settings = Bindable(settings)
        return SettingsView(
            appearance: settings.appearance,
            accentColor: settings.accentColor,
            showsWeeks: settings.showsWeeks,
            showsSeconds: settings.showsSeconds,
            milestoneAlerts: settings.milestoneAlerts,
            isSupporter: supportStore.isSupporter,
            syncsWithICloud: settings.syncsWithICloud,
            syncState: { [cloudSync] in cloudSync.state },
            importer: { [self] in importView() },
            support: { [self] in supportSheet() },
            cloudSync: { [self] in cloudSyncView() }
        )
    }

    private func cloudSyncView() -> some View {
        CloudSyncView(
            syncsWithICloud: Bindable(settings).syncsWithICloud,
            state: { [cloudSync] in cloudSync.state },
            checkAgain: { [cloudSync] in await cloudSync.checkAccount() },
            repairs: CloudSyncRepairs(
                downloadAgain: { [self] in
                    try cloudSyncRepair.downloadAgain()
                    repaired()
                },
                uploadAgain: { [self] in
                    try await cloudSyncRepair.uploadAgain()
                    repaired()
                },
                removeFromICloud: { [self] in
                    try await cloudSyncRepair.removeFromICloud()
                    settings.syncsWithICloud = false
                    repaired()
                }
            ),
            prepareSchema: Self.prepareSchema
        )
    }

    #if DEBUG
    // Off the main thread: it uploads to iCloud and can take a while.
    private static let prepareSchema: (() async throws -> Void)? = { try await Task.detached { try EventDatabase.initializeCloudKitSchema() }.value }
    #else
    private static let prepareSchema: (() async throws -> Void)? = nil
    #endif

    private func supportSheet() -> some View {
        SupportSheet {
            SupportView(store: supportStore) { [settings] isUnlocked in
                AppThemeSection(isUnlocked: isUnlocked, theme: Bindable(settings).theme) { name in
                    try await UIApplication.shared.setAlternateIconName(name)
                }
            }
        }
    }

    private func onboardingView() -> some View {
        OnboardingView(
            holidayRegion: settings.holidayRegion,
            syncsWithICloud: Bindable(settings).syncsWithICloud,
            hasSyncedBefore: { await CloudKitEventsChecker(containerIdentifier: AppGroup.cloudContainer).hasSyncedBefore() },
            importer: { [self] in importView() },
            onFinish: { [repository, settings] events, birthday in
                repository.save(events)
                if let birthday { settings.birthday = birthday }
                settings.hasCompletedOnboarding = true
            }
        )
    }

    /// Links from widgets and notifications, and `.timity` files received from others.
    private func open(_ url: URL) {
        guard url.isFileURL else {
            navigator.open(url)
            return
        }
        do {
            navigator.addEvent(from: try ReceivedEventFile.draft(at: url))
        } catch {
            logger.error("Couldn't open the event file: \(error)")
        }
    }
}
