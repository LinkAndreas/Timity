import Foundation

/// An event as a `.timity` file, for sending a copy to someone else. Opening the
/// file in Timity adds the event to their own list.
struct EventFile: Codable, Equatable, Sendable {
    static let fileExtension = "timity"
    /// The exported type identifier, declared in the app's Info.plist.
    static let typeIdentifier = "de.link.timity.event"

    var version = 1
    var title: String
    /// As stored in `Event.date`: for all-day events, midnight UTC of the day.
    var date: Date
    var isAllDay: Bool
    var recurrence: String
    var color: String
    var symbolName: String
    var notes: String
    var timeZoneIdentifier: String?
    var isYearUnknown: Bool
    var imageData: Data?

    init(_ snapshot: EventSnapshot, notes: String = "") {
        title = snapshot.title
        date = snapshot.date
        isAllDay = snapshot.isAllDay
        recurrence = snapshot.recurrence.rawValue
        color = snapshot.color.rawValue
        symbolName = snapshot.symbolName
        self.notes = notes
        timeZoneIdentifier = snapshot.timeZoneIdentifier
        isYearUnknown = snapshot.isYearUnknown
        imageData = snapshot.imageData
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> EventFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(EventFile.self, from: data)
    }

    /// A file name from the event's title, safe for every file system.
    var fileName: String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-").trimmingCharacters(in: .whitespaces)
        return "\(cleaned.isEmpty ? "Event" : cleaned).\(Self.fileExtension)"
    }
}
