import CoreData
import Foundation
import Observation
import SwiftData
import Synchronization

/// Events in one SwiftData store in the app group, so the widgets read what the
/// app writes, mirrored to the user's private iCloud database when the user wants.
///
/// It holds the store this process has open; the app reopens it to turn iCloud
/// sync on or off, and everything reading events reads from whichever is open.
final class EventDatabase: Sendable {
    private struct Opened {
        var container: ModelContainer
        /// Whether it really syncs: it opens without iCloud when iCloud can't be set up.
        var syncs: Bool
    }

    private let current: Mutex<Opened>
    private let inMemory: Bool

    /// - Parameter syncsWithICloud: The apps sync; extensions (widgets,
    ///   complications) only read the store and leave syncing to the apps.
    init(syncsWithICloud: Bool, inMemory: Bool = false) {
        self.inMemory = inMemory
        current = Mutex(Self.open(syncsWithICloud: syncsWithICloud, inMemory: inMemory))
    }

    var container: ModelContainer {
        current.withLock { $0.container }
    }

    /// Whether the open store syncs with iCloud.
    var syncsWithICloud: Bool {
        current.withLock { $0.syncs }
    }

    /// Opens the same store again, with or without iCloud. The store it replaces
    /// closes, so only one ever syncs.
    func reopen(syncsWithICloud: Bool) {
        current.withLock { $0 = Self.open(syncsWithICloud: syncsWithICloud, inMemory: inMemory) }
    }

    private static func open(syncsWithICloud: Bool, inMemory: Bool) -> Opened {
        let effectiveInMemory = inMemory || isRunningTests
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)

        if !effectiveInMemory, let groupURL {
            let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        }

        let useAppGroup = !effectiveInMemory && groupURL != nil
        let schema = Schema([Event.self])
        func configuration(cloud: Bool) -> ModelConfiguration {
            ModelConfiguration(
                "Timity",
                schema: schema,
                isStoredInMemoryOnly: effectiveInMemory,
                allowsSave: true,
                groupContainer: useAppGroup ? .identifier(AppGroup.identifier) : .none,
                cloudKitDatabase: cloud ? .private(AppGroup.cloudContainer) : .none
            )
        }

        // Simulators signed in to iCloud sync too, so sync can be tried out there.
        if syncsWithICloud && !effectiveInMemory {
            do {
                return Opened(container: try ModelContainer(for: schema, configurations: configuration(cloud: true)), syncs: true)
            } catch {
                // Without iCloud entitlements (e.g. a build without a team)
                // the app still works with the same store, just without syncing.
                logger.error("Couldn't open the iCloud store: \(error)")
            }
        }
        do {
            return Opened(container: try ModelContainer(for: schema, configurations: configuration(cloud: false)), syncs: false)
        } catch {
            logger.fault("Couldn't open the store, falling back to memory: \(error)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store can't fail to open.
            return Opened(container: try! ModelContainer(for: schema, configurations: memory), syncs: false)
        }
    }

    /// The fields an event syncs with. A new one only syncs from App Store builds
    /// once the CloudKit schema with it is deployed to production.
    static var syncedFieldNames: [String] {
        Schema([Event.self]).entities.flatMap { $0.attributes.map(\.name) }.sorted()
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    #if DEBUG
    /// Creates the event record type and all its fields in iCloud's development
    /// environment, from a scratch store, so the schema can be deployed to
    /// production in the CloudKit Console. Without that, App Store and TestFlight
    /// builds can't upload events with fields production doesn't know yet.
    static func initializeCloudKitSchema() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TimitySchema-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: AppGroup.cloudContainer)
        description.shouldAddStoreAsynchronously = false
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [Event.self]) else { return }
        let container = NSPersistentCloudKitContainer(name: "TimitySchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        defer {
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
            try? FileManager.default.removeItem(at: url)
        }
        try container.initializeCloudKitSchema()
    }
    #endif
}

/// Reads every event, one per ID, with a context of its own, so it sees the store as it is now.
struct SwiftDataEventReader: EventReader {
    let database: EventDatabase

    func fetchEvents() -> [EventSnapshot] {
        let context = ModelContext(database.container)
        return ((try? context.fetch(FetchDescriptor<Event>())) ?? []).map(\.snapshot).oneByID
    }
}

/// The app's events, reloaded after every change made here, in another process
/// (a widget) or through iCloud.
@MainActor
@Observable
final class SwiftDataEventRepository: EventRepository {
    private(set) var events: [EventSnapshot] = []

    @ObservationIgnored private let database: EventDatabase
    @ObservationIgnored private var remoteChanges: Task<Void, Never>?

    init(database: EventDatabase) {
        self.database = database
        reload()
        remoteChanges = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                self?.reload()
            }
        }
    }

    /// Reads the store again — after iCloud or a widget changed it.
    func reload() {
        let latest = SwiftDataEventReader(database: database).fetchEvents()
        if latest != events { events = latest }
    }

    func save(_ snapshots: [EventSnapshot]) {
        guard !snapshots.isEmpty else { return }
        let context = ModelContext(database.container)
        for snapshot in snapshots {
            // Every copy of the event, should another device have stored it too.
            let copies = records(snapshot.id, in: context)
            if copies.isEmpty {
                let record = Event()
                record.update(from: snapshot)
                context.insert(record)
            } else {
                copies.forEach { $0.update(from: snapshot) }
            }
        }
        commit(context)
    }

    func delete(_ id: UUID) {
        let context = ModelContext(database.container)
        let copies = records(id, in: context)
        guard !copies.isEmpty else { return }
        copies.forEach(context.delete)
        commit(context)
    }

    private func records(_ id: UUID, in context: ModelContext) -> [Event] {
        (try? context.fetch(FetchDescriptor<Event>(predicate: #Predicate { $0.id == id }))) ?? []
    }

    private func commit(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Couldn't save events: \(error)")
        }
        reload()
    }
}

// MARK: - The stored record

/// How an event is stored and synced through iCloud. Nothing outside this file
/// sees it; everything else works with `EventSnapshot`.
///
/// The class name is the CloudKit record type, so it must stay `Event`. Every
/// property has a default and nothing is unique, as CloudKit requires.
/// Enumerations are stored as their raw values, so a newer app version adding a
/// case can't break an older one reading the same iCloud data.
@Model
private final class Event {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date.now
    var isAllDay: Bool = false
    var recurrenceRawValue: String = Recurrence.never.rawValue
    var colorRawValue: String = EventColor.orange.rawValue
    var symbolName: String = EventSymbol.defaultName
    var notes: String = ""
    var isPinned: Bool = false
    var reminderMinutes: Int? = nil
    @Attribute(.externalStorage) var imageData: Data? = nil
    var timeZoneIdentifier: String? = nil
    var listName: String = ""
    var isArchived: Bool = false
    var isYearUnknown: Bool = false
    var recurrenceInterval: Int = 1
    /// A `RecurrenceRule.Pattern` raw value.
    var recurrencePatternRawValue: String = RecurrenceRule.Pattern.sameDay.rawValue
    /// An `EventCalendar` raw value; empty for the user's own calendar.
    var calendarRawValue: String = ""
    var showsProgress: Bool = false
    var progressStart: Date? = nil
    /// When earlier streaks began, as JSON dates.
    var resetHistoryData: Data? = nil
    /// The checklist, as JSON `ChecklistItem`s.
    var checklistData: Data? = nil
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    init() {}

    var snapshot: EventSnapshot {
        EventSnapshot(
            id: id,
            title: title,
            date: date,
            isAllDay: isAllDay,
            recurrence: Recurrence(rawValue: recurrenceRawValue) ?? .never,
            color: EventColor(rawValue: colorRawValue) ?? .orange,
            symbolName: symbolName,
            isPinned: isPinned,
            imageData: imageData,
            timeZoneIdentifier: isAllDay ? nil : timeZoneIdentifier,
            listName: listName,
            isArchived: isArchived,
            isYearUnknown: isYearUnknown,
            recurrenceInterval: max(1, recurrenceInterval),
            recurrencePattern: RecurrenceRule.Pattern(rawValue: recurrencePatternRawValue) ?? .sameDay,
            eventCalendar: EventCalendar(rawValue: calendarRawValue),
            showsProgress: showsProgress,
            progressStart: progressStart,
            notes: notes,
            reminderMinutes: reminderMinutes,
            resetHistory: resetHistoryData.flatMap { try? JSONDecoder().decode([Date].self, from: $0) } ?? [],
            checklist: Checklist.decode(checklistData),
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Takes the snapshot's values, writing only those that changed, so iCloud
    /// uploads no more than it has to — above all not the photo.
    func update(from snapshot: EventSnapshot) {
        func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Event, Value>, _ value: Value) {
            if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
        }
        set(\.id, snapshot.id)
        set(\.title, snapshot.title)
        set(\.date, snapshot.date)
        set(\.isAllDay, snapshot.isAllDay)
        set(\.recurrenceRawValue, snapshot.recurrence.rawValue)
        set(\.colorRawValue, snapshot.color.rawValue)
        set(\.symbolName, snapshot.symbolName)
        set(\.notes, snapshot.notes)
        set(\.isPinned, snapshot.isPinned)
        set(\.reminderMinutes, snapshot.reminderMinutes)
        set(\.imageData, snapshot.imageData)
        set(\.timeZoneIdentifier, snapshot.isAllDay ? nil : snapshot.timeZoneIdentifier)
        set(\.listName, snapshot.listName)
        set(\.isArchived, snapshot.isArchived)
        set(\.isYearUnknown, snapshot.isYearUnknown)
        set(\.recurrenceInterval, max(1, snapshot.recurrenceInterval))
        set(\.recurrencePatternRawValue, snapshot.recurrencePattern.rawValue)
        set(\.calendarRawValue, snapshot.eventCalendar?.rawValue ?? "")
        set(\.showsProgress, snapshot.showsProgress)
        set(\.progressStart, snapshot.progressStart)
        set(\.resetHistoryData, snapshot.resetHistory.isEmpty ? nil : try? JSONEncoder().encode(snapshot.resetHistory))
        set(\.checklistData, Checklist.encode(snapshot.checklist))
        set(\.createdAt, snapshot.createdAt)
        set(\.modifiedAt, snapshot.modifiedAt)
    }
}
