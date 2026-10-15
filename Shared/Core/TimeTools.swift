import Foundation

/// Durations as people write them: "1:45", "1.75" or "1h 45m".
enum HoursMath {
    /// Seconds for a written duration, or `nil` if it can't be read. Hours and
    /// minutes ("1:45"), hours, minutes and seconds ("1:45:30"), decimal hours
    /// ("1.75" or "1,75") and units ("1h 45m", "90m") all work; a leading minus
    /// makes it negative.
    static func seconds(from text: String) -> TimeInterval? {
        var input = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !input.isEmpty else { return nil }
        var sign: Double = 1
        if input.hasPrefix("-") || input.hasPrefix("−") {
            sign = -1
            input.removeFirst()
        }

        if input.contains(":") {
            let parts = input.split(separator: ":", omittingEmptySubsequences: false).map { Double($0) }
            guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
            let values = parts.map { $0! }
            guard values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
            let total = values[0] * 3600 + values[1] * 60 + (values.count == 3 ? values[2] : 0)
            return sign * total
        }

        if input.contains(where: { "hms".contains($0) }) {
            var total: Double = 0
            var number = ""
            var found = false
            for character in input {
                if character.isNumber || character == "." || character == "," {
                    number.append(character == "," ? "." : character)
                } else if "hms".contains(character), let value = Double(number) {
                    total += value * (character == "h" ? 3600 : character == "m" ? 60 : 1)
                    number = ""
                    found = true
                } else if !character.isWhitespace {
                    return nil
                }
            }
            guard found, number.isEmpty else { return nil }
            return sign * total
        }

        guard let hours = Double(input.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return sign * hours * 3600
    }

    /// "1:45" — hours and minutes, rounded to the minute; negative with a minus.
    static func clockText(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int((abs(seconds) / 60).rounded())
        let text = String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
        return seconds < 0 && totalMinutes > 0 ? "−" + text : text
    }

    /// Decimal hours, e.g. 1.75.
    static func decimalHours(_ seconds: TimeInterval) -> Double {
        seconds / 3600
    }

    /// The time from one clock time to another, overnight when the end is
    /// earlier than the start — a 22:00 to 06:00 shift is 8 hours.
    static func span(from start: DateComponents, to end: DateComponents) -> TimeInterval {
        let startSeconds = (start.hour ?? 0) * 3600 + (start.minute ?? 0) * 60
        var endSeconds = (end.hour ?? 0) * 3600 + (end.minute ?? 0) * 60
        if endSeconds <= startSeconds { endSeconds += 24 * 3600 }
        return TimeInterval(endSeconds - startSeconds)
    }
}

/// Facts about an age, from a birth date.
struct AgeFacts: Sendable {
    let age: TimeBreakdown
    let totalDays: Int
    let totalWeeks: Int
    let nextBirthday: Date
    let daysToNextBirthday: Int
    let nextHalfBirthday: Date
    /// 1 for Sunday through 7 for Saturday, in the calendar given.
    let weekdayOfBirth: Int
    let planetAges: [(planet: Planet, years: Double)]

    enum Planet: String, CaseIterable, Sendable {
        case mercury, venus, mars, jupiter, saturn

        /// Orbital period in Earth years.
        var orbitalPeriod: Double {
            switch self {
            case .mercury: 0.2408467
            case .venus: 0.61519726
            case .mars: 1.8808158
            case .jupiter: 11.862615
            case .saturn: 29.447498
            }
        }
    }

    init(birth: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        age = DateMath.breakdown(between: birth, and: max(birth, now), includeWeeks: false, calendar: calendar)
        let days = max(0, DateMath.calendarDays(from: birth, to: now, calendar: calendar))
        totalDays = days
        totalWeeks = days / 7
        let birthday = RecurrenceRule(frequency: .yearly).occurrence(of: birth, onOrAfter: now, calendar: calendar).date
        nextBirthday = birthday
        daysToNextBirthday = max(0, DateMath.calendarDays(from: now, to: birthday, calendar: calendar))
        // Half birthdays are six months off the birthday, every year.
        let halfStart = calendar.date(byAdding: .month, value: 6, to: birth) ?? birth
        nextHalfBirthday = RecurrenceRule(frequency: .yearly).occurrence(of: halfStart, onOrAfter: now, calendar: calendar).date
        weekdayOfBirth = calendar.component(.weekday, from: birth)
        let earthYears = Double(days) / 365.2422
        planetAges = Planet.allCases.map { ($0, earthYears / $0.orbitalPeriod) }
    }
}

/// How far through the current day, week, month and year a moment is.
enum PeriodProgress {
    enum Period: String, CaseIterable, Identifiable, Sendable {
        case day, week, month, year

        var id: String { rawValue }

        var component: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            }
        }
    }

    struct Progress: Equatable, Sendable {
        let interval: DateInterval
        /// From 0 to 1.
        let elapsed: Double
        let remaining: TimeInterval
    }

    static func progress(of period: Period, at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Progress {
        let interval = calendar.dateInterval(of: period.component, for: date) ?? DateInterval(start: date, duration: 1)
        let elapsed = date.timeIntervalSince(interval.start) / interval.duration
        return Progress(interval: interval, elapsed: min(max(elapsed, 0), 1), remaining: interval.end.timeIntervalSince(date))
    }
}

/// Streaks for "since" counters that can start over, such as days without smoking.
struct Streaks: Equatable, Sendable {
    /// The current streak's length in calendar days.
    let current: Int
    /// The longest streak, the current one included.
    let longest: Int
    /// How many times the counter started over.
    let resets: Int

    /// - Parameters:
    ///   - start: When the current streak began.
    ///   - previousStarts: When earlier streaks began, in any order; each ended
    ///     where the next one began.
    init(start: Date, previousStarts: [Date], now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let starts = (previousStarts + [start]).sorted()
        var lengths: [Int] = []
        for (index, begin) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1] : now
            lengths.append(max(0, DateMath.calendarDays(from: begin, to: end, calendar: calendar)))
        }
        current = lengths.last ?? 0
        longest = lengths.max() ?? 0
        resets = previousStarts.count
    }
}

/// Bedtimes and wake-up times that fall between sleep cycles of about 90
/// minutes, so waking comes at the end of one rather than in deep sleep.
enum SleepCycles {
    struct Option: Hashable, Sendable {
        let cycles: Int
        let time: Date
        var cycleLength: TimeInterval = SleepCycles.cycle

        /// The sleep itself, without the time it takes to fall asleep.
        var sleep: TimeInterval { TimeInterval(cycles) * cycleLength }

        /// Whether it's within the seven to nine hours most adults need.
        var isRecommended: Bool { SleepCycles.recommendedSleep.contains(sleep) }
    }

    static let cycle: TimeInterval = 90 * 60
    /// About how long it takes to fall asleep.
    static let fallingAsleep: TimeInterval = 15 * 60
    /// Six cycles (9 hours) to four (6 hours), the most sleep first.
    static let choices = [6, 5, 4]
    /// What most adults need a night.
    static let recommendedSleep: ClosedRange<TimeInterval> = 7 * 3600...9 * 3600
    /// The sleep the suggestion aims for: the middle of the recommended range.
    static let idealSleep: TimeInterval = 8 * 3600

    /// When to go to bed to wake up rested at `wake`, the most sleep first.
    static func bedtimes(
        toWakeAt wake: Date,
        cycles: [Int] = choices,
        cycleLength: TimeInterval = cycle,
        fallingAsleep: TimeInterval = fallingAsleep
    ) -> [Option] {
        cycles.map {
            Option(cycles: $0, time: wake.addingTimeInterval(-TimeInterval($0) * cycleLength - fallingAsleep), cycleLength: cycleLength)
        }
    }

    /// When to wake up rested after going to bed at `bedtime`, the most sleep first.
    static func wakeTimes(
        goingToBedAt bedtime: Date,
        cycles: [Int] = choices,
        cycleLength: TimeInterval = cycle,
        fallingAsleep: TimeInterval = fallingAsleep
    ) -> [Option] {
        cycles.map {
            Option(cycles: $0, time: bedtime.addingTimeInterval(TimeInterval($0) * cycleLength + fallingAsleep), cycleLength: cycleLength)
        }
    }

    /// The number of cycles that comes closest to eight hours of sleep: five of
    /// 90 minutes, six of 80. Shorter sleep wins a tie, to stay within the range.
    static func bestCycles(cycleLength: TimeInterval = cycle) -> Int {
        guard cycleLength > 0 else { return 5 }
        let exact = idealSleep / cycleLength
        let lower = exact.rounded(.down), upper = exact.rounded(.up)
        let closest = idealSleep - lower * cycleLength <= upper * cycleLength - idealSleep ? lower : upper
        return max(1, Int(closest))
    }
}

/// A pregnancy dated from the first day of the last period, by Naegele's rule:
/// the baby is due 280 days, 40 weeks, later.
struct Pregnancy: Equatable, Sendable {
    static let length = 280

    let dueDate: Date
    /// Completed weeks and days since the last period, e.g. 12 weeks and 3 days.
    let weeks: Int
    let days: Int
    let daysToGo: Int

    init(lastPeriod: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let start = calendar.startOfDay(for: lastPeriod)
        dueDate = calendar.date(byAdding: .day, value: Self.length, to: start) ?? start
        let elapsed = max(0, calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0)
        weeks = elapsed / 7
        days = elapsed % 7
        daysToGo = max(0, Self.length - elapsed)
    }

    /// 1 to 3: weeks 0–12, 13–26, and 27 on.
    var trimester: Int {
        weeks < 13 ? 1 : weeks < 27 ? 2 : 3
    }

    var progress: Double {
        min(1, Double(weeks * 7 + days) / Double(Self.length))
    }
}
