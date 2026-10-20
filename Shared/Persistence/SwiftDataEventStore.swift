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
nonisolated final class EventDatabase: Sendable {
    nonisolated private struct Opened {
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
        // A store in memory never syncs, and opening it again would start it empty.
        guard !inMemory, !Self.isRunningTests else { return }
        current.withLock { $0 = Self.open(syncsWithICloud: syncsWithICloud, inMemory: inMemory) }
    }

    /// Deletes the store on this device, with its photos and what it knows of
    /// iCloud, and opens a new, empty one. With iCloud, that one downloads every
    /// event again; without, it starts afresh.
    func eraseAndReopen(syncsWithICloud: Bool) throws {
        try current.withLock { opened in
            let url = opened.container.configurations.first?.url
            // Let go of the store before deleting it.
            opened = Opened(container: Self.placeholder(), syncs: false)
            if let url, !inMemory {
                try NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
                    .destroyPersistentStore(at: url, type: .sqlite)
                let photos = url.deletingLastPathComponent().appendingPathComponent(".\(url.deletingPathExtension().lastPathComponent)_SUPPORT")
                try? FileManager.default.removeItem(at: photos)
            }
            opened = Self.open(syncsWithICloud: syncsWithICloud, inMemory: inMemory)
        }
    }

    private static func placeholder() -> ModelContainer {
        // An in-memory store can't fail to open.
        try! ModelContainer(for: currentSchema, migrationPlan: EventMigrationPlan.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private static func open(syncsWithICloud: Bool, inMemory: Bool) -> Opened {
        let effectiveInMemory = inMemory || isRunningTests
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)

        // The Mac gives a group container's path even when the app may not use it, as in a
        // build signed without the app group; the store then stays in the app's own container
        // rather than in memory, where events would be gone at the next launch. Creating the
        // folder can succeed there while writing into it is denied, so a file is written to check.
        var canUseGroup = false
        if !effectiveInMemory, let groupURL {
            let appSupportURL = groupURL.appendingPathComponent("Library/Application Support", isDirectory: true)
            let probeURL = appSupportURL.appendingPathComponent(".write-check")
            canUseGroup = (try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)) != nil
                && FileManager.default.createFile(atPath: probeURL.path, contents: Data())
            try? FileManager.default.removeItem(at: probeURL)
        }

        let useAppGroup = !effectiveInMemory && canUseGroup
        let schema = currentSchema
        // Each store in memory under a name of its own, so tests running side by side
        // (and the app hosting them) never share events.
        let name = effectiveInMemory ? "Timity-\(UUID().uuidString)" : "Timity"
        func configuration(cloud: Bool) -> ModelConfiguration {
            ModelConfiguration(
                name,
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
                return Opened(container: try ModelContainer(for: schema, migrationPlan: EventMigrationPlan.self, configurations: configuration(cloud: true)), syncs: true)
            } catch {
                // Without iCloud entitlements (e.g. a build without a team)
                // the app still works with the same store, just without syncing.
                logger.error("Couldn't open the iCloud store: \(error)")
            }
        }
        do {
            return Opened(container: try ModelContainer(for: schema, migrationPlan: EventMigrationPlan.self, configurations: configuration(cloud: false)), syncs: false)
        } catch {
            logger.fault("Couldn't open the store, falling back to memory: \(error)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store can't fail to open.
            return Opened(container: try! ModelContainer(for: schema, migrationPlan: EventMigrationPlan.self, configurations: memory), syncs: false)
        }
    }

    /// The schema stores open with: the newest version in the migration plan.
    private static var currentSchema: Schema {
        Schema(versionedSchema: EventMigrationPlan.schemas.last!)
    }

    /// The fields an event syncs with. A new one only syncs from App Store builds
    /// once the CloudKit schema with it is deployed to production.
    static var syncedFieldNames: [String] {
        currentSchema.entities.flatMap { $0.attributes.map(\.name) }.sorted()
    }

    /// Every schema version in the migration plan, oldest first.
    static var schemaVersions: [Schema.Version] {
        EventMigrationPlan.schemas.map { $0.versionIdentifier }
    }

    /// Fields a schema version drops or renames from the one before, which iCloud
    /// can't do: its production schema only ever gains fields. Empty when every
    /// version keeps all the fields of the last.
    static var fieldsDroppedBetweenVersions: [String] {
        let fields = EventMigrationPlan.schemas.map { version in
            Set(Schema(versionedSchema: version).entities.flatMap { entity in entity.attributes.map { "\(entity.name).\($0.name)" } })
        }
        return zip(fields, fields.dropFirst()).flatMap { older, newer in older.subtracting(newer) }.sorted()
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
nonisolated struct SwiftDataEventReader: EventReader {
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

// How events are stored and synced through iCloud. Nothing outside this file sees
// it; everything else works with `EventSnapshot`.
//
// The model is versioned so the store can move to a new shape later. The rules,
// set by iCloud, whose production schema only ever gains fields:
//
// - Never rename or delete a property, or change its type; older app versions on
//   the user's other devices still read and write it. Stop using it instead, as
//   `checklistData` shows.
// - New properties need a default value (or are optional), and nothing is unique.
// - To change the model, copy the newest `EventSchemaV…` to a new version with a
//   higher `versionIdentifier`, make the change there, leave the older versions as
//   they are, add the new one to `EventMigrationPlan.schemas` with a lightweight
//   stage, and point `Event` at it. Then follow "Changing the data model" in
//   Docs/Setup.md to deploy the CloudKit schema before releasing.

/// The first versioned model: events as Timity 4 has always stored them.
nonisolated private enum EventSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Event.self] }

    /// The class name is the CloudKit record type, so it must stay `Event` in every
    /// version. Enumerations are stored as their raw values, so a newer app version
    /// adding a case can't break an older one reading the same iCloud data.
    @Model
    nonisolated final class Event {
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
        /// Checklists from earlier versions, no longer shown. The field stays, as it's deployed
        /// in CloudKit and older versions still sync it; Timity neither reads nor writes it.
        var checklistData: Data? = nil
        var createdAt: Date = Date.now
        var modifiedAt: Date = Date.now

        init() {}
    }
}

/// How the store moves from one schema version to the next. Each step must be
/// lightweight — new fields with defaults only — as iCloud can't migrate data.
nonisolated private enum EventMigrationPlan: SchemaMigrationPlan {
    /// Oldest first; the last is the one stores open with.
    static var schemas: [any VersionedSchema.Type] { [EventSchemaV1.self] }

    /// One `.lightweight(fromVersion:toVersion:)` per step between versions.
    static var stages: [MigrationStage] { [] }
}

/// The newest stored event, which the rest of this file works with.
private typealias Event = EventSchemaV1.Event

/// Between the store and the rest of the app, whichever version is newest.
nonisolated extension Event {
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
        set(\.createdAt, snapshot.createdAt)
        set(\.modifiedAt, snapshot.modifiedAt)
    }
}
