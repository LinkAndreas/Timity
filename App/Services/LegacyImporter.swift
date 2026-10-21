import CoreData
import Foundation

/// Brings data over from Timity 3: its events, which it kept in a Core Data store
/// in the Documents folder, and the last place the Sun tab found. Events are
/// imported once; the old store is left in place, untouched.
nonisolated enum LegacyImporter {
    private static let doneKey = "didImportTimity3Events"

    /// The colour Timity 3 showed everything in, which its events keep; `nil` when never changed.
    static func highlightColor(in defaults: KeyValueStore) -> EventColor? {
        switch defaults.string(forKey: "highlightColor") {
        case "teal blue": .teal
        case let name?: EventColor(rawValue: name)
        case nil: nil
        }
    }

    /// Timity 3's events that haven't come over yet, their photos as Timity 3 kept them; empty
    /// without Timity 3 or once they've come over. Someone with some is welcomed back to the new
    /// Timity and chooses which to bring along. A store that can't be read is tried again next launch.
    static func pendingEvents(in defaults: KeyValueStore) -> [EventSnapshot] {
        guard !defaults.bool(forKey: doneKey) else { return [] }

        guard
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.fileExists(atPath: documents.appendingPathComponent("Timity.sqlite").path)
        else {
            defaults.set(true, forKey: doneKey)
            return []
        }

        do {
            let records = try legacyEvents(at: documents.appendingPathComponent("Timity.sqlite"))
            // Someone who never added an event is as good as new, and welcomed as such.
            if records.isEmpty { defaults.set(true, forKey: doneKey) }
            let color = highlightColor(in: defaults) ?? .orange
            let sorted = records.sorted { $0.date < $1.date }
            let ids = eventIDs(for: sorted.map { ($0.title, $0.date) })
            return zip(sorted, ids)
                .map { record, id in
                    var event = EventSnapshot(
                        id: id,
                        title: record.title,
                        date: record.date,
                        imageData: record.imageData,
                        createdAt: record.createdAt ?? record.date
                    )
                    event.color = color
                    return event
                }
        } catch {
            logger.error("Couldn't read Timity 3 events: \(error)")
            return []
        }
    }

    /// The IDs of Timity 3's events, in order: the same on every device that had the event in
    /// Timity 3, which never synced, so the copies typed in on each become one once iCloud brings
    /// them together. By name and day rather than the second, which two copies hardly share;
    /// same-named events on one day stay apart.
    static func eventIDs(for events: [(title: String, date: Date)], calendar: Calendar = .autoupdatingCurrent) -> [UUID] {
        var seen: [String: Int] = [:]
        return events.map { title, date in
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            let key = "timity3|\(title)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
            let count = seen[key, default: 0] + 1
            seen[key] = count
            return UUID(stableFrom: count == 1 ? key : "\(key)|\(count)")
        }
    }

    /// Brings the chosen events over, one by one, each photo made ready for iCloud on the way, and
    /// tells how many have come so far. The rest stay behind in Timity 3's store, left untouched;
    /// either way the choice is made, and isn't offered again.
    @MainActor
    static func move(
        _ events: [EventSnapshot],
        into repository: any EventRepository,
        defaults: KeyValueStore,
        progress: (Int) -> Void = { _ in }
    ) async {
        for (index, var event) in events.enumerated() {
            if let photo = event.imageData {
                event.imageData = await ImageProcessing.prepareForStorage(photo) ?? photo
            }
            repository.save([event])
            progress(index + 1)
        }
        defaults.set(true, forKey: doneKey)
        logger.info("Moved \(events.count) events over from Timity 3")
    }

    /// The last place Timity 3 and earlier versions of Timity 4 found, kept in the app's own defaults.
    static func place(in defaults: KeyValueStore) -> Place? {
        guard
            let coordinate = defaults.object(forKey: "lastLocation") as? [String: Double],
            let latitude = coordinate["latitude"],
            let longitude = coordinate["longitude"]
        else { return nil }
        return Place(
            latitude: latitude,
            longitude: longitude,
            timeZoneIdentifier: defaults.string(forKey: "lastLocationTimeZone") ?? TimeZone.autoupdatingCurrent.identifier,
            name: defaults.string(forKey: "lastLocationName")
        )
    }

    nonisolated private struct LegacyEvent {
        let title: String
        let date: Date
        let createdAt: Date?
        let imageData: Data?
    }

    private static func legacyEvents(at url: URL) throws -> [LegacyEvent] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: legacyModel)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSReadOnlyPersistentStoreOption: true]
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Event")
            return try context.fetch(request).compactMap { object in
                guard let date = object.value(forKey: "dateOfEvent") as? Date else { return nil }
                let name = (object.value(forKey: "nameOfEvent") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return LegacyEvent(
                    title: name?.isEmpty == false ? name! : String(localized: "common.event"),
                    date: date,
                    createdAt: object.value(forKey: "dateOfCreation") as? Date,
                    imageData: object.value(forKey: "imageOfEvent") as? Data
                )
            }
        }
    }

    /// Timity 3's model, rebuilt in code so the old model file needn't ship.
    private static var legacyModel: NSManagedObjectModel {
        func attribute(_ name: String, _ type: NSAttributeType) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = true
            return attribute
        }

        let reminderMinutes = attribute("minutesToSetReminderOfEvent", .floatAttributeType)
        reminderMinutes.defaultValue = 0.0

        let entity = NSEntityDescription()
        entity.name = "Event"
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [
            attribute("dateOfCreation", .dateAttributeType),
            attribute("dateOfEvent", .dateAttributeType),
            attribute("imageOfEvent", .binaryDataAttributeType),
            reminderMinutes,
            attribute("nameOfEvent", .stringAttributeType),
            attribute("reminderEnabled", .booleanAttributeType),
            attribute("reminderOfEvent", .binaryDataAttributeType),
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
