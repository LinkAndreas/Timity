import Foundation
import CoreData

extension Event {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var dateOfCreation: Date?
    @NSManaged public var dateOfEvent: Date?
    @NSManaged public var imageOfEvent: Data?
    @NSManaged public var minutesToSetReminderOfEvent: Float
    @NSManaged public var nameOfEvent: String?
    @NSManaged public var reminderEnabled: Bool
    @NSManaged public var reminderOfEvent: Data?
}
