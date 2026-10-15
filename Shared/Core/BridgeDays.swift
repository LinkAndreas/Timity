import Foundation

/// Stretches of time off around public holidays: a few days of leave that join
/// a holiday and a weekend into a long break — Easter, Ascension, Christmas.
nonisolated enum BridgeDays {
    nonisolated struct Opportunity: Hashable, Identifiable, Sendable {
        /// The first and last day off, both included.
        let start: Date
        let end: Date
        /// Working days to take as leave.
        let leaveDays: [Date]
        /// The holidays inside the break, by name.
        let holidays: [String]

        var id: Date { start }

        var daysOff: Int {
            (Calendar.gregorianUTC.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        }
    }

    /// The best breaks in `year`, most days off per day of leave first, spending at
    /// most `maxLeave` days on one break.
    static func opportunities(
        in year: Int,
        region: HolidayRegion,
        maxLeave: Int = 4,
        calendar: Calendar = .gregorianUTC
    ) -> [Opportunity] {
        let holidays = region.namedHolidays(in: year)
        var names: [Date: String] = [:]
        for holiday in holidays {
            if let date = calendar.date(from: holiday.date) { names[date] = holiday.name }
        }
        guard let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let last = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) else { return [] }

        func isWeekend(_ day: Date) -> Bool { calendar.isDateInWeekend(day) }
        func isOff(_ day: Date) -> Bool { isWeekend(day) || names[day] != nil }
        func add(_ days: Int, _ day: Date) -> Date { calendar.date(byAdding: .day, value: days, to: day) ?? day }

        var found: [Opportunity] = []
        // Every holiday that falls on a working day is a starting point.
        for holiday in names.keys.sorted() where !isWeekend(holiday) && holiday >= first && holiday <= last {
            // Try spending leave on days before and after it.
            for before in 0...maxLeave {
                for after in 0...(maxLeave - before) where before + after > 0 {
                    var start = holiday, end = holiday, leave: [Date] = []
                    var ok = true
                    for _ in 0..<before {
                        start = add(-1, start)
                        while isOff(start) { start = add(-1, start) }
                        leave.append(start)
                    }
                    for _ in 0..<after {
                        end = add(1, end)
                        while isOff(end) { end = add(1, end) }
                        leave.append(end)
                    }
                    // Widen to the days off on either side.
                    while isOff(add(-1, start)) { start = add(-1, start) }
                    while isOff(add(1, end)) { end = add(1, end) }
                    if start < first || end > last { ok = false }
                    guard ok else { continue }
                    let inside = stride(from: 0, through: calendar.dateComponents([.day], from: start, to: end).day ?? 0, by: 1)
                        .map { add($0, start) }
                    let opportunity = Opportunity(
                        start: start,
                        end: end,
                        leaveDays: leave.sorted(),
                        holidays: inside.compactMap { names[$0] }
                    )
                    // Worth it: at least twice as many days off as days of leave.
                    if opportunity.daysOff >= 2 * leave.count + 1 { found.append(opportunity) }
                }
            }
        }

        // The best break per stretch of the year, so the list doesn't repeat itself.
        let ranked = found.sorted {
            let a = Double($0.daysOff) / Double($0.leaveDays.count), b = Double($1.daysOff) / Double($1.leaveDays.count)
            return a != b ? a > b : $0.daysOff > $1.daysOff
        }
        var chosen: [Opportunity] = []
        for candidate in ranked where !chosen.contains(where: { $0.start <= candidate.end && candidate.start <= $0.end }) {
            chosen.append(candidate)
        }
        return chosen.sorted { $0.start < $1.start }
    }
}

/// When a flight lands, in the time at its destination.
nonisolated enum FlightArrival {
    nonisolated struct Result: Equatable, Sendable {
        let arrival: Date
        /// Calendar days between the departure date and the arrival date, both local: +1 lands the next day.
        let dayChange: Int
        /// The destination's offset from the origin, in seconds, at arrival.
        let timeDifference: Int
    }

    static func arrival(departure: Date, from origin: TimeZone, duration: TimeInterval, to destination: TimeZone) -> Result {
        let arrival = departure.addingTimeInterval(duration)
        var originCalendar = Calendar(identifier: .gregorian)
        originCalendar.timeZone = origin
        var destinationCalendar = Calendar(identifier: .gregorian)
        destinationCalendar.timeZone = destination
        let departureDay = originCalendar.dateComponents([.year, .month, .day], from: departure)
        let arrivalDay = destinationCalendar.dateComponents([.year, .month, .day], from: arrival)
        let utc = Calendar.gregorianUTC
        let dayChange = utc.dateComponents([.day], from: utc.date(from: departureDay) ?? departure, to: utc.date(from: arrivalDay) ?? arrival).day ?? 0
        return Result(
            arrival: arrival,
            dayChange: dayChange,
            timeDifference: destination.secondsFromGMT(for: arrival) - origin.secondsFromGMT(for: departure)
        )
    }
}

nonisolated extension Calendar {
    /// The Gregorian calendar in UTC, for whole days that don't shift with time zones.
    static let gregorianUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
}
