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
    /// Every how many periods the event repeats, from 1.
    var recurrenceInterval: Int = 1
    /// A `RecurrenceRule.Pattern` raw value.
    var recurrencePatternRawValue: String = RecurrenceRule.Pattern.sameDay.rawValue
    /// An `EventCalendar` raw value for yearly events in another calendar; empty for the user's own.
    var calendarRawValue: String = ""
    /// Whether the countdown shows how much of the wait has passed.
    var showsProgress: Bool = false
    /// Where progress starts for one-off events; `nil` for when the event was added.
    var progressStart: Date? = nil
    /// When earlier streaks of a "since" counter began, as JSON dates.
    var resetHistoryData: Data? = nil
    /// The event's checklist, as JSON `ChecklistItem`s.
    var checklistData: Data? = nil
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

    var recurrenceRule: RecurrenceRule {
        get {
            RecurrenceRule(
                frequency: recurrence,
                interval: max(1, recurrenceInterval),
                pattern: RecurrenceRule.Pattern(rawValue: recurrencePatternRawValue) ?? .sameDay,
                calendarIdentifier: recurrence == .yearly ? EventCalendar(rawValue: calendarRawValue)?.identifier : nil
            )
        }
    }

    var eventCalendar: EventCalendar? {
        get { EventCalendar(rawValue: calendarRawValue) }
        set { calendarRawValue = newValue?.rawValue ?? "" }
    }

    /// When earlier streaks began, for counters that were started over.
    var resetHistory: [Date] {
        get { resetHistoryData.flatMap { try? JSONDecoder().decode([Date].self, from: $0) } ?? [] }
        set { resetHistoryData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }

    var checklist: [ChecklistItem] {
        get { Checklist.decode(checklistData) }
        set { checklistData = Checklist.encode(newValue) }
    }

    /// Starts a "since" counter over from now, keeping the old start in the history.
    func startOver(at now: Date = .now, calendar: Calendar = .autoupdatingCurrent) {
        resetHistory = resetHistory + [startDate(in: calendar)]
        setStartDate(isAllDay ? calendar.startOfDay(for: now) : now, calendar: calendar)
        modifiedAt = now
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
            isYearUnknown: isYearUnknown,
            recurrenceInterval: max(1, recurrenceInterval),
            recurrencePattern: RecurrenceRule.Pattern(rawValue: recurrencePatternRawValue) ?? .sameDay,
            eventCalendar: EventCalendar(rawValue: calendarRawValue),
            showsProgress: showsProgress,
            progressStart: progressStart ?? createdAt
        )
    }
}
