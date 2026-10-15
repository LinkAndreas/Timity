import Foundation

/// A unit Timity counts time in, largest first.
nonisolated enum TimeUnit: String, CaseIterable, Identifiable, Sendable {
    case year, month, week, day, hour, minute, second

    var id: String { rawValue }

    var calendarComponent: Calendar.Component {
        switch self {
        case .year: .year
        case .month: .month
        case .week: .weekOfYear
        case .day: .day
        case .hour: .hour
        case .minute: .minute
        case .second: .second
        }
    }
}

/// One part of a breakdown, such as "3 weeks".
nonisolated struct TimePart: Hashable, Identifiable, Sendable {
    let unit: TimeUnit
    let value: Int

    var id: TimeUnit { unit }
}

/// The span between two moments as calendar parts — "2 years, 3 months, 1 week, 4 days" —
/// each a whole, non-negative number. The direction lives in `TimeDirection`.
nonisolated struct TimeBreakdown: Hashable, Sendable {
    var years = 0
    var months = 0
    var weeks = 0
    var days = 0
    var hours = 0
    var minutes = 0
    var seconds = 0

    func value(of unit: TimeUnit) -> Int {
        switch unit {
        case .year: years
        case .month: months
        case .week: weeks
        case .day: days
        case .hour: hours
        case .minute: minutes
        case .second: seconds
        }
    }

    var isZero: Bool {
        TimeUnit.allCases.allSatisfy { value(of: $0) == 0 }
    }

    /// The parts to show, largest first. Zero parts are left out, except that seconds
    /// are always shown when asked for, so a live countdown never changes length.
    func parts(includingSeconds: Bool) -> [TimePart] {
        TimeUnit.allCases.compactMap { unit in
            if unit == .second {
                return includingSeconds ? TimePart(unit: unit, value: seconds) : nil
            }
            let value = value(of: unit)
            return value == 0 ? nil : TimePart(unit: unit, value: value)
        }
    }
}

/// The span between two moments expressed entirely in one unit at a time:
/// "1.5 years" or "18.3 months" or "548 days".
nonisolated struct TimeTotals: Hashable, Sendable {
    var years: Double = 0
    var months: Double = 0
    var weeks: Double = 0
    var days: Double = 0
    var hours: Double = 0
    var minutes: Double = 0
    var seconds: Double = 0

    func value(of unit: TimeUnit) -> Double {
        switch unit {
        case .year: years
        case .month: months
        case .week: weeks
        case .day: days
        case .hour: hours
        case .minute: minutes
        case .second: seconds
        }
    }
}

/// Where a moment lies relative to another.
nonisolated enum TimeDirection: Sendable {
    case past
    case present
    case future
}
