import Foundation

/// A round number of units since an event: 10,000 days, 1,000 weeks, a billion seconds.
nonisolated struct Milestone: Hashable, Identifiable, Sendable {
    let unit: TimeUnit
    /// 64-bit, as a billion seconds doesn't fit in the Watch's 32-bit `Int`.
    let value: Int64
    let date: Date

    var id: String { "\(unit.rawValue)-\(value)" }
}

/// Milestones since a date — a birthday, an anniversary, the day someone quit smoking.
nonisolated enum Milestones {
    /// The round numbers worth celebrating in each unit.
    static let values: [TimeUnit: [Int64]] = [
        .year: [],
        .month: [100, 200, 250, 300, 400, 500, 600, 750, 1000],
        .week: [100, 250, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000],
        .day: [100, 200, 365, 500, 1000, 2000, 2500, 3000, 4000, 5000, 6000, 7000, 7500, 8000, 9000,
               10_000, 11_111, 12_000, 12_345, 15_000, 20_000, 22_222, 25_000, 30_000, 33_333, 35_000, 40_000],
        .hour: [1000, 10_000, 100_000, 200_000, 250_000, 300_000, 400_000, 500_000, 750_000, 1_000_000],
        .minute: [1_000_000, 5_000_000, 10_000_000, 20_000_000, 25_000_000, 30_000_000, 40_000_000, 50_000_000],
        .second: [100_000_000, 500_000_000, 1_000_000_000, 1_500_000_000, 2_000_000_000, 2_500_000_000, 3_000_000_000],
    ]

    /// Every milestone since `start`, in date order.
    static func all(since start: Date, calendar: Calendar = .autoupdatingCurrent) -> [Milestone] {
        TimeUnit.allCases.flatMap { unit in
            (values[unit] ?? []).compactMap { value in
                date(start, plus: value, unit, calendar: calendar).map { Milestone(unit: unit, value: value, date: $0) }
            }
        }
        .sorted { $0.date < $1.date }
    }

    /// The next milestones after `now`, soonest first.
    static func upcoming(
        since start: Date,
        after now: Date,
        limit: Int = 3,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Milestone] {
        guard start < now else { return [] }
        return Array(all(since: start, calendar: calendar).filter { $0.date > now }.prefix(limit))
    }

    /// The most recent milestone before `now`, if it was within `window`.
    static func recent(
        since start: Date,
        before now: Date,
        within window: TimeInterval = 7 * 86_400,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Milestone? {
        all(since: start, calendar: calendar)
            .last { $0.date <= now && now.timeIntervalSince($0.date) <= window }
    }

    private static func date(_ start: Date, plus value: Int64, _ unit: TimeUnit, calendar: Calendar) -> Date? {
        // Calendar units are at most tens of thousands, which fit any `Int`.
        let count = Int(clamping: value)
        return switch unit {
        case .year:
            calendar.date(byAdding: .year, value: count, to: start)
        case .month:
            calendar.date(byAdding: .month, value: count, to: start)
        case .week:
            // Days rather than calendar weeks, so it's exactly 7 × value days.
            calendar.date(byAdding: .day, value: count * 7, to: start)
        case .day:
            calendar.date(byAdding: .day, value: count, to: start)
        case .hour, .minute, .second:
            // Elapsed time: a billion seconds is a billion seconds, whatever the clocks did.
            start.addingTimeInterval(Double(value) * (unit == .hour ? 3600 : unit == .minute ? 60 : 1))
        }
    }
}
