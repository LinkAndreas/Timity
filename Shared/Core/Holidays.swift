import Foundation

/// Countries whose nationwide public holidays Timity knows, for counting working days.
/// Regional holidays (a German state's, a Swiss canton's) aren't included.
enum HolidayRegion: String, CaseIterable, Identifiable, Sendable {
    case germany = "DE"
    case austria = "AT"
    case switzerland = "CH"
    case france = "FR"
    case italy = "IT"
    case spain = "ES"
    case netherlands = "NL"
    case unitedKingdom = "GB"
    case unitedStates = "US"

    var id: String { rawValue }

    /// The region of `locale`, if Timity knows its holidays.
    init?(locale: Locale) {
        guard let code = locale.region?.identifier, let region = HolidayRegion(rawValue: code) else { return nil }
        self = region
    }

    /// The country's name in the user's language.
    func localizedName(locale: Locale = .autoupdatingCurrent) -> String {
        locale.localizedString(forRegionCode: rawValue) ?? rawValue
    }

    /// The days off in `year`, as year, month and day.
    func holidays(in year: Int) -> [DateComponents] {
        let easter = Holidays.easterSunday(year)
        func fixed(_ month: Int, _ day: Int) -> DateComponents { DateComponents(year: year, month: month, day: day) }
        func fromEaster(_ days: Int) -> DateComponents { Holidays.adding(days, to: easter) }

        let goodFriday = fromEaster(-2)
        let easterMonday = fromEaster(1)
        let ascension = fromEaster(39)
        let whitMonday = fromEaster(50)
        let corpusChristi = fromEaster(60)

        switch self {
        case .germany:
            return [fixed(1, 1), goodFriday, easterMonday, fixed(5, 1), ascension, whitMonday,
                    fixed(10, 3), fixed(12, 25), fixed(12, 26)]
        case .austria:
            return [fixed(1, 1), fixed(1, 6), easterMonday, fixed(5, 1), ascension, whitMonday, corpusChristi,
                    fixed(8, 15), fixed(10, 26), fixed(11, 1), fixed(12, 8), fixed(12, 25), fixed(12, 26)]
        case .switzerland:
            return [fixed(1, 1), goodFriday, easterMonday, ascension, whitMonday, fixed(8, 1),
                    fixed(12, 25), fixed(12, 26)]
        case .france:
            return [fixed(1, 1), easterMonday, fixed(5, 1), fixed(5, 8), ascension, whitMonday,
                    fixed(7, 14), fixed(8, 15), fixed(11, 1), fixed(11, 11), fixed(12, 25)]
        case .italy:
            return [fixed(1, 1), fixed(1, 6), easterMonday, fixed(4, 25), fixed(5, 1), fixed(6, 2),
                    fixed(8, 15), fixed(11, 1), fixed(12, 8), fixed(12, 25), fixed(12, 26)]
        case .spain:
            return [fixed(1, 1), fixed(1, 6), goodFriday, fixed(5, 1), fixed(8, 15), fixed(10, 12),
                    fixed(11, 1), fixed(12, 6), fixed(12, 8), fixed(12, 25)]
        case .netherlands:
            // King's Day moves to the 26th when the 27th is a Sunday.
            let kingsDay = Holidays.weekday(fixed(4, 27)) == 1 ? fixed(4, 26) : fixed(4, 27)
            return [fixed(1, 1), easterMonday, kingsDay, fixed(5, 5), ascension, whitMonday,
                    fixed(12, 25), fixed(12, 26)]
        case .unitedKingdom:
            // England and Wales; a holiday on a weekend moves to the next weekday.
            let christmas = Holidays.substitutes([fixed(12, 25), fixed(12, 26)])
            return [Holidays.substitutes([fixed(1, 1)])[0], goodFriday, easterMonday,
                    Holidays.nthWeekday(1, weekday: 2, month: 5, year: year),
                    Holidays.lastWeekday(2, month: 5, year: year),
                    Holidays.lastWeekday(2, month: 8, year: year)] + christmas
        case .unitedStates:
            // Federal holidays; Saturday ones are observed on Friday, Sunday ones on Monday.
            let observed = [fixed(1, 1), fixed(6, 19), fixed(7, 4), fixed(11, 11), fixed(12, 25)].map(Holidays.observedUS)
            return observed + [
                Holidays.nthWeekday(3, weekday: 2, month: 1, year: year),   // Martin Luther King Jr. Day
                Holidays.nthWeekday(3, weekday: 2, month: 2, year: year),   // Presidents' Day
                Holidays.lastWeekday(2, month: 5, year: year),              // Memorial Day
                Holidays.nthWeekday(1, weekday: 2, month: 9, year: year),   // Labor Day
                Holidays.nthWeekday(2, weekday: 2, month: 10, year: year),  // Columbus Day
                Holidays.nthWeekday(4, weekday: 5, month: 11, year: year),  // Thanksgiving
            ]
        }
    }
}

/// Calendar arithmetic for holidays, always in the Gregorian calendar.
enum Holidays {
    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Easter Sunday by the anonymous Gregorian algorithm.
    static func easterSunday(_ year: Int) -> DateComponents {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return DateComponents(year: year, month: month, day: day)
    }

    static func adding(_ days: Int, to components: DateComponents) -> DateComponents {
        guard
            let date = gregorian.date(from: components),
            let moved = gregorian.date(byAdding: .day, value: days, to: date)
        else { return components }
        // Only year, month and day, so results compare equal to literals.
        let parts = gregorian.dateComponents([.year, .month, .day], from: moved)
        return DateComponents(year: parts.year, month: parts.month, day: parts.day)
    }

    /// 1 for Sunday through 7 for Saturday.
    static func weekday(_ components: DateComponents) -> Int {
        gregorian.date(from: components).map { gregorian.component(.weekday, from: $0) } ?? 0
    }

    /// The `n`th `weekday` (1 = Sunday) of a month, e.g. the third Monday of January.
    static func nthWeekday(_ n: Int, weekday: Int, month: Int, year: Int) -> DateComponents {
        let first = DateComponents(year: year, month: month, day: 1)
        let offset = (weekday - self.weekday(first) + 7) % 7
        return adding(offset + (n - 1) * 7, to: first)
    }

    /// The last `weekday` (1 = Sunday) of a month, e.g. the last Monday of May.
    static func lastWeekday(_ weekday: Int, month: Int, year: Int) -> DateComponents {
        let nextMonth = month == 12 ? DateComponents(year: year + 1, month: 1, day: 1) : DateComponents(year: year, month: month + 1, day: 1)
        let last = adding(-1, to: nextMonth)
        let offset = (self.weekday(last) - weekday + 7) % 7
        return adding(-offset, to: last)
    }

    /// US federal rule: Saturday holidays are observed on Friday, Sunday ones on Monday.
    static func observedUS(_ components: DateComponents) -> DateComponents {
        switch weekday(components) {
        case 7: adding(-1, to: components)
        case 1: adding(1, to: components)
        default: components
        }
    }

    /// UK rule: holidays on a weekend move to the next weekday that isn't already a holiday.
    static func substitutes(_ days: [DateComponents]) -> [DateComponents] {
        var taken: [DateComponents] = []
        for day in days {
            var candidate = day
            while [1, 7].contains(weekday(candidate)) || taken.contains(candidate) {
                candidate = adding(1, to: candidate)
            }
            taken.append(candidate)
        }
        return taken
    }
}

extension DateMath {
    /// Working days between two dates, leaving out weekends and the region's public holidays.
    static func workingDays(
        between first: Date,
        and second: Date,
        region: HolidayRegion?,
        includingLastDay: Bool = false,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let weekdays = weekdays(between: first, and: second, includingLastDay: includingLastDay, calendar: calendar)
        guard let region else { return weekdays }

        let start = calendar.startOfDay(for: min(first, second))
        var end = calendar.startOfDay(for: max(first, second))
        if includingLastDay { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }

        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)
        guard startYear <= endYear else { return weekdays }

        let holidays = Set((startYear...endYear).flatMap(region.holidays(in:)))
            .compactMap { calendar.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day)) }
            .filter { $0 >= start && $0 < end && !calendar.isDateInWeekend($0) }
        return max(0, weekdays - holidays.count)
    }
}
