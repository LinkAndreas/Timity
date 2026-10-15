import Foundation

/// Countries whose nationwide public holidays Timity knows, for counting working days.
/// Regional holidays (a German state's, a Swiss canton's) aren't included.
nonisolated enum HolidayRegion: String, CaseIterable, Identifiable, Sendable {
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
        namedHolidays(in: year).map(\.date)
    }

    /// The days off in `year` with their names in the country's own language, as
    /// people there know them.
    func namedHolidays(in year: Int) -> [PublicHoliday] {
        let easter = Holidays.easterSunday(year)
        func fixed(_ month: Int, _ day: Int) -> DateComponents { DateComponents(year: year, month: month, day: day) }
        func fromEaster(_ days: Int) -> DateComponents { Holidays.adding(days, to: easter) }
        func named(_ list: [(String, DateComponents)]) -> [PublicHoliday] {
            list.map { PublicHoliday(name: $0.0, date: $0.1) }
        }

        let goodFriday = fromEaster(-2)
        let easterMonday = fromEaster(1)
        let ascension = fromEaster(39)
        let whitMonday = fromEaster(50)
        let corpusChristi = fromEaster(60)

        switch self {
        case .germany:
            return named([("Neujahr", fixed(1, 1)), ("Karfreitag", goodFriday), ("Ostermontag", easterMonday),
                          ("Tag der Arbeit", fixed(5, 1)), ("Christi Himmelfahrt", ascension), ("Pfingstmontag", whitMonday),
                          ("Tag der Deutschen Einheit", fixed(10, 3)), ("1. Weihnachtstag", fixed(12, 25)), ("2. Weihnachtstag", fixed(12, 26))])
        case .austria:
            return named([("Neujahr", fixed(1, 1)), ("Heilige Drei Könige", fixed(1, 6)), ("Ostermontag", easterMonday),
                          ("Staatsfeiertag", fixed(5, 1)), ("Christi Himmelfahrt", ascension), ("Pfingstmontag", whitMonday),
                          ("Fronleichnam", corpusChristi), ("Mariä Himmelfahrt", fixed(8, 15)), ("Nationalfeiertag", fixed(10, 26)),
                          ("Allerheiligen", fixed(11, 1)), ("Mariä Empfängnis", fixed(12, 8)), ("Christtag", fixed(12, 25)),
                          ("Stefanitag", fixed(12, 26))])
        case .switzerland:
            return named([("Neujahr", fixed(1, 1)), ("Karfreitag", goodFriday), ("Ostermontag", easterMonday),
                          ("Auffahrt", ascension), ("Pfingstmontag", whitMonday), ("Bundesfeier", fixed(8, 1)),
                          ("Weihnachten", fixed(12, 25)), ("Stephanstag", fixed(12, 26))])
        case .france:
            return named([("Jour de l’An", fixed(1, 1)), ("Lundi de Pâques", easterMonday), ("Fête du Travail", fixed(5, 1)),
                          ("Victoire 1945", fixed(5, 8)), ("Ascension", ascension), ("Lundi de Pentecôte", whitMonday),
                          ("Fête nationale", fixed(7, 14)), ("Assomption", fixed(8, 15)), ("Toussaint", fixed(11, 1)),
                          ("Armistice", fixed(11, 11)), ("Noël", fixed(12, 25))])
        case .italy:
            return named([("Capodanno", fixed(1, 1)), ("Epifania", fixed(1, 6)), ("Lunedì dell’Angelo", easterMonday),
                          ("Festa della Liberazione", fixed(4, 25)), ("Festa del Lavoro", fixed(5, 1)),
                          ("Festa della Repubblica", fixed(6, 2)), ("Ferragosto", fixed(8, 15)), ("Ognissanti", fixed(11, 1)),
                          ("Immacolata Concezione", fixed(12, 8)), ("Natale", fixed(12, 25)), ("Santo Stefano", fixed(12, 26))])
        case .spain:
            return named([("Año Nuevo", fixed(1, 1)), ("Epifanía del Señor", fixed(1, 6)), ("Viernes Santo", goodFriday),
                          ("Fiesta del Trabajo", fixed(5, 1)), ("Asunción de la Virgen", fixed(8, 15)),
                          ("Fiesta Nacional de España", fixed(10, 12)), ("Todos los Santos", fixed(11, 1)),
                          ("Día de la Constitución", fixed(12, 6)), ("Inmaculada Concepción", fixed(12, 8)), ("Navidad", fixed(12, 25))])
        case .netherlands:
            // King's Day moves to the 26th when the 27th is a Sunday.
            let kingsDay = Holidays.weekday(fixed(4, 27)) == 1 ? fixed(4, 26) : fixed(4, 27)
            return named([("Nieuwjaarsdag", fixed(1, 1)), ("Tweede Paasdag", easterMonday), ("Koningsdag", kingsDay),
                          ("Bevrijdingsdag", fixed(5, 5)), ("Hemelvaartsdag", ascension), ("Tweede Pinksterdag", whitMonday),
                          ("Eerste Kerstdag", fixed(12, 25)), ("Tweede Kerstdag", fixed(12, 26))])
        case .unitedKingdom:
            // England and Wales; a holiday on a weekend moves to the next weekday.
            let christmas = Holidays.substitutes([fixed(12, 25), fixed(12, 26)])
            return named([("New Year’s Day", Holidays.substitutes([fixed(1, 1)])[0]), ("Good Friday", goodFriday),
                          ("Easter Monday", easterMonday),
                          ("Early May Bank Holiday", Holidays.nthWeekday(1, weekday: 2, month: 5, year: year)),
                          ("Spring Bank Holiday", Holidays.lastWeekday(2, month: 5, year: year)),
                          ("Summer Bank Holiday", Holidays.lastWeekday(2, month: 8, year: year)),
                          ("Christmas Day", christmas[0]), ("Boxing Day", christmas[1])])
        case .unitedStates:
            // Federal holidays; Saturday ones are observed on Friday, Sunday ones on Monday.
            return named([("New Year’s Day", Holidays.observedUS(fixed(1, 1))),
                          ("Martin Luther King Jr. Day", Holidays.nthWeekday(3, weekday: 2, month: 1, year: year)),
                          ("Presidents’ Day", Holidays.nthWeekday(3, weekday: 2, month: 2, year: year)),
                          ("Memorial Day", Holidays.lastWeekday(2, month: 5, year: year)),
                          ("Juneteenth", Holidays.observedUS(fixed(6, 19))),
                          ("Independence Day", Holidays.observedUS(fixed(7, 4))),
                          ("Labor Day", Holidays.nthWeekday(1, weekday: 2, month: 9, year: year)),
                          ("Columbus Day", Holidays.nthWeekday(2, weekday: 2, month: 10, year: year)),
                          ("Veterans Day", Holidays.observedUS(fixed(11, 11))),
                          ("Thanksgiving", Holidays.nthWeekday(4, weekday: 5, month: 11, year: year)),
                          ("Christmas Day", Holidays.observedUS(fixed(12, 25)))])
        }
    }
}

/// A public holiday's name and date.
nonisolated struct PublicHoliday: Hashable, Sendable {
    let name: String
    let date: DateComponents
}

/// Calendar arithmetic for holidays, always in the Gregorian calendar.
nonisolated enum Holidays {
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

nonisolated extension DateMath {
    /// `date` moved by `count` working days — weekdays that aren't the region's
    /// public holidays — forwards, or backwards when `count` is negative. The time
    /// of day stays; a start on a day off counts from the next working day.
    static func date(
        _ date: Date,
        addingWorkingDays count: Int,
        region: HolidayRegion?,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let step = count < 0 ? -1 : 1
        var holidayCache: [Int: Set<DateComponents>] = [:]
        func isWorkingDay(_ day: Date) -> Bool {
            guard !calendar.isDateInWeekend(day) else { return false }
            guard let region else { return true }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let year = parts.year ?? 0
            if holidayCache[year] == nil { holidayCache[year] = Set(region.holidays(in: year)) }
            return !(holidayCache[year]?.contains(DateComponents(year: parts.year, month: parts.month, day: parts.day)) ?? false)
        }

        var current = date
        var remaining = abs(count)
        // Up to about 20 years of working days; enough for any deadline.
        var guardSteps = 0
        while remaining > 0, guardSteps < 10_000 {
            guard let next = calendar.date(byAdding: .day, value: step, to: current) else { return nil }
            current = next
            guardSteps += 1
            if isWorkingDay(current) { remaining -= 1 }
        }
        return current
    }

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
