import Foundation
import SwiftData

/// An event Timity counts towards or since, synced through iCloud.
///
/// Every property has a default and nothing is unique, as CloudKit requires.
/// Enumerations are stored as their raw values, so a newer app version adding a
/// case can't break an older one reading the same iCloud data.
@Model
final class Event {
    var id: UUID = UUID()
    var title: String = ""
    /// The moment of the event. For all-day events, midnight UTC of its day — see
    /// `FloatingDay` — so the day is the same in every time zone.
    var date: Date = Date.now
    var isAllDay: Bool = false
    var recurrenceRawValue: String = Recurrence.never.rawValue
    var colorRawValue: String = EventColor.orange.rawValue
    var symbolName: String = EventSymbol.defaultName
    var notes: String = ""
    var isPinned: Bool = false
    /// Minutes before the event to send a reminder; `nil` for none. For all-day
    /// events, minutes before 9:00 on the day.
    var reminderMinutes: Int? = nil
    @Attribute(.externalStorage) var imageData: Data? = nil
    /// The time zone a timed event happens in, such as a flight landing in Tokyo;
    /// `nil` for the user's own time zone.
    var timeZoneIdentifier: String? = nil
    /// The list the event belongs to, such as "Family" or "Work"; empty for none.
    var listName: String = ""
    var isArchived: Bool = false
    /// For birthdays imported without a year: the date's year is a placeholder,
    /// so no age is shown.
    var isYearUnknown: Bool = false
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    init(
        title: String,
        date: Date,
        isAllDay: Bool = false,
        recurrence: Recurrence = .never,
        color: EventColor = .orange,
        symbolName: String = EventSymbol.defaultName
    ) {
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.recurrenceRawValue = recurrence.rawValue
        self.colorRawValue = color.rawValue
        self.symbolName = symbolName
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRawValue) ?? .never }
        set { recurrenceRawValue = newValue.rawValue }
    }

    var color: EventColor {
        get { EventColor(rawValue: colorRawValue) ?? .orange }
        set { colorRawValue = newValue.rawValue }
    }

    /// The event's date as a moment in `calendar`: all-day events start at local midnight.
    func startDate(in calendar: Calendar = .autoupdatingCurrent) -> Date {
        isAllDay ? FloatingDay.localDate(fromStored: date, calendar: calendar) : date
    }

    /// Stores `localDate` as the event's date, as a day when the event is all-day.
    func setStartDate(_ localDate: Date, calendar: Calendar = .autoupdatingCurrent) {
        date = isAllDay ? FloatingDay.storedDate(forDayOf: localDate, calendar: calendar) : localDate
    }

    var timeZone: TimeZone? {
        get { isAllDay ? nil : timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) }
        set { timeZoneIdentifier = newValue?.identifier }
    }

    var snapshot: EventSnapshot {
        EventSnapshot(
            id: id,
            title: title,
            date: date,
            isAllDay: isAllDay,
            recurrence: recurrence,
            color: color,
            symbolName: symbolName,
            isPinned: isPinned,
            imageData: imageData,
            timeZoneIdentifier: isAllDay ? nil : timeZoneIdentifier,
            listName: listName,
            isArchived: isArchived,
            isYearUnknown: isYearUnknown
        )
    }
}
