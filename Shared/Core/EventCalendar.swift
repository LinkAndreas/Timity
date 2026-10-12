import Foundation

/// The calendars a yearly event can follow besides the user's own — for birthdays
/// and holidays kept by the lunar or another traditional calendar.
enum EventCalendar: String, CaseIterable, Identifiable, Codable, Sendable {
    case chinese
    case hebrew
    case islamic
    case persian
    case indian

    var id: String { rawValue }

    var identifier: Calendar.Identifier {
        switch self {
        case .chinese: .chinese
        case .hebrew: .hebrew
        case .islamic: .islamicUmmAlQura
        case .persian: .persian
        case .indian: .indian
        }
    }

    /// A calendar of this kind in the time zone and language of `base`.
    func calendar(basedOn base: Calendar = .autoupdatingCurrent) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = base.timeZone
        calendar.locale = base.locale
        return calendar
    }
}
