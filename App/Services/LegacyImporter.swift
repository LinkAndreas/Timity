import CoreData
import Foundation
import SwiftData

/// Brings events over from Timity 3, which kept them in a Core Data store in the
/// Documents folder. Runs once; the old store is left in place, untouched.
enum LegacyImporter {
    private static let doneKey = "didImportTimity3Events"

    static func importIfNeeded(into container: ModelContainer, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }

        guard
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.fileExists(atPath: documents.appendingPathComponent("Timity.sqlite").path)
        else {
            defaults.set(true, forKey: doneKey)
            return
        }

        do {
            let records = try legacyEvents(at: documents.appendingPathComponent("Timity.sqlite"))
            let context = ModelContext(container)
            for record in records {
                let event = Event(title: record.title, date: record.date)
                event.createdAt = record.createdAt ?? record.date
                event.imageData = record.imageData.flatMap(ImageProcessing.preparedForStorage) ?? record.imageData
                context.insert(event)
            }
            try context.save()
            defaults.set(true, forKey: doneKey)
            logger.info("Imported \(records.count) events from Timity 3")
        } catch {
            // Tried again next launch.
            logger.error("Couldn't import Timity 3 events: \(error)")
        }
    }

    private struct LegacyEvent {
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
                    title: name?.isEmpty == false ? name! : String(localized: "Event"),
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
