import Contacts
import EventKit
import Foundation

/// An event found in Contacts or Calendar, before it's imported.
struct ImportCandidate: Identifiable, Hashable {
    enum Source: Hashable {
        case birthday
        case anniversary
        case calendar
        case holiday
    }

    let id: String
    let title: String
    /// For all-day candidates, any time on the day.
    let date: Date
    let isAllDay: Bool
    let isYearUnknown: Bool
    let source: Source

    var recurrence: Recurrence {
        source == .calendar || source == .holiday ? .never : .yearly
    }

    var symbolName: String {
        switch source {
        case .birthday: "birthday.cake.fill"
        case .anniversary: "heart.fill"
        case .calendar: "calendar"
        case .holiday: "flag.fill"
        }
    }

    var color: EventColor {
        switch source {
        case .birthday: .pink
        case .anniversary: .red
        case .calendar: .blue
        case .holiday: .red
        }
    }
}

extension ImportCandidate {
    /// The event the candidate becomes once imported.
    var event: EventSnapshot {
        var event = EventSnapshot(
            title: title,
            isAllDay: isAllDay,
            recurrence: recurrence,
            color: color,
            symbolName: symbolName,
            isYearUnknown: isYearUnknown
        )
        event.setStartDate(date)
        event.listName = switch source {
        case .calendar: ""
        case .holiday: String(localized: "Holidays")
        case .birthday, .anniversary: String(localized: "Birthdays")
        }
        return event
    }
}

enum ImportError: Error {
    case accessDenied
}

/// Birthdays and anniversaries from Contacts.
enum ContactsImport {
    /// A leap year, so 29 February birthdays without a year survive; the year itself is never shown.
    static let placeholderYear = 2000

    static func candidates() async throws -> [ImportCandidate] {
        let store = CNContactStore()
        guard try await store.requestAccess(for: .contacts) else { throw ImportError.accessDenied }

        return try await Task.detached(priority: .userInitiated) {
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactDatesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var results: [ImportCandidate] = []
            let calendar = Calendar.autoupdatingCurrent

            try store.enumerateContacts(with: request) { contact, _ in
                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                guard !name.isEmpty else { return }

                if let birthday = contact.birthday, let day = ContactsImport.day(from: birthday, calendar: calendar) {
                    results.append(ImportCandidate(
                        id: "birthday-\(contact.identifier)",
                        title: String(localized: "birthday.title \(name)"),
                        date: day.date,
                        isAllDay: true,
                        isYearUnknown: day.isYearUnknown,
                        source: .birthday
                    ))
                }
                for labeled in contact.dates where labeled.label == CNLabelDateAnniversary {
                    if let day = ContactsImport.day(from: labeled.value as DateComponents, calendar: calendar) {
                        results.append(ImportCandidate(
                            id: "anniversary-\(contact.identifier)-\(labeled.identifier)",
                            title: String(localized: "anniversary.title \(name)"),
                            date: day.date,
                            isAllDay: true,
                            isYearUnknown: day.isYearUnknown,
                            source: .anniversary
                        ))
                    }
                }
            }
            return results.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }.value
    }

    private static func day(from components: DateComponents, calendar: Calendar) -> (date: Date, isYearUnknown: Bool)? {
        guard let month = components.month, let day = components.day else { return nil }
        let year = components.year
        guard let date = calendar.date(from: DateComponents(year: year ?? placeholderYear, month: month, day: day)) else {
            return nil
        }
        return (date, year == nil)
    }
}

/// Upcoming events from Calendar.
enum CalendarImport {
    static func candidates(monthsAhead: Int = 12) async throws -> [ImportCandidate] {
        let store = EKEventStore()
        guard try await store.requestFullAccessToEvents() else { throw ImportError.accessDenied }

        let now = Date.now
        let end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: monthsAhead, to: now) ?? now
        // Birthdays come from Contacts, without the calendar's yearly copies.
        let calendars = store.calendars(for: .event).filter { $0.type != .birthday }
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)

        var seen = Set<String>()
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                // A repeating meeting would otherwise appear once per occurrence.
                guard let title = event.title, !title.isEmpty, seen.insert(event.calendarItemExternalIdentifier ?? event.eventIdentifier).inserted
                else { return nil }
                return ImportCandidate(
                    id: "calendar-\(event.eventIdentifier ?? UUID().uuidString)",
                    title: title,
                    date: event.startDate,
                    isAllDay: event.isAllDay,
                    isYearUnknown: false,
                    source: .calendar
                )
            }
    }
}

/// The region's public holidays in the next twelve months, each a one-off event —
/// movable holidays such as Easter fall on other days every year.
enum HolidayImport {
    static func candidates(region: HolidayRegion, from now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [ImportCandidate] {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        let year = calendar.component(.year, from: today)
        return [year, year + 1]
            .flatMap { region.namedHolidays(in: $0) }
            .compactMap { holiday -> ImportCandidate? in
                guard let date = calendar.date(from: holiday.date), date >= today, date < end else { return nil }
                return ImportCandidate(
                    id: "holiday-\(region.rawValue)-\(holiday.name)-\(date.timeIntervalSince1970)",
                    title: holiday.name,
                    date: date,
                    isAllDay: true,
                    isYearUnknown: false,
                    source: .holiday
                )
            }
            .sorted { $0.date < $1.date }
    }
}
