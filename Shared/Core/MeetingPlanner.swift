import Foundation

/// When a call suits several cities: the stretches of a day that fall within
/// working hours everywhere, and how each city's clock reads at a moment.
nonisolated enum MeetingPlanner {
    /// The part of a city's day an hour falls in.
    nonisolated enum DayPart: Hashable, Sendable {
        /// 9:00 to 17:00.
        case working
        /// 7:00 to 9:00.
        case morning
        /// 17:00 to 22:00.
        case evening
        /// 22:00 to 7:00.
        case night

        init(hour: Int) {
            switch hour {
            case 9..<17: self = .working
            case 7..<9: self = .morning
            case 17..<22: self = .evening
            default: self = .night
            }
        }
    }

    static let workingHours = 9..<17
    /// Half hours, so cities half an hour off, such as Mumbai, still line up.
    static let step: TimeInterval = 30 * 60

    /// The day part `moment` falls in for `zone`.
    static func dayPart(at moment: Date, in zone: TimeZone) -> DayPart {
        DayPart(hour: calendar(in: zone).component(.hour, from: moment))
    }

    /// The stretches of the local day around `day` in which every zone is within
    /// working hours, earliest first.
    static func windows(on day: Date, zones: [TimeZone], calendar local: Calendar = .autoupdatingCurrent) -> [DateInterval] {
        guard !zones.isEmpty else { return [] }
        let start = local.startOfDay(for: day)
        guard let end = local.date(byAdding: .day, value: 1, to: start) else { return [] }
        let calendars = zones.map(calendar(in:))

        var windows: [DateInterval] = []
        var openedAt: Date?
        var slot = start
        while slot < end {
            let suitsEveryone = calendars.allSatisfy { calendar in
                let parts = calendar.dateComponents([.hour, .minute], from: slot)
                return workingHours.contains(parts.hour ?? 0)
            }
            if suitsEveryone, openedAt == nil {
                openedAt = slot
            } else if !suitsEveryone, let opened = openedAt {
                windows.append(DateInterval(start: opened, end: slot))
                openedAt = nil
            }
            slot = slot.addingTimeInterval(step)
        }
        if let opened = openedAt {
            windows.append(DateInterval(start: opened, end: end))
        }
        return windows
    }

    /// How far `zone`'s clock is ahead of `reference`'s at `moment`, in seconds;
    /// negative when it's behind.
    static func offset(of zone: TimeZone, from reference: TimeZone, at moment: Date) -> Int {
        zone.secondsFromGMT(for: moment) - reference.secondsFromGMT(for: moment)
    }

    /// -1 when it's still the day before in `zone`, 1 when it's already the next
    /// day, 0 on the same day as in `reference`.
    static func dayDifference(of zone: TimeZone, from reference: TimeZone, at moment: Date) -> Int {
        let there = calendar(in: zone).dateComponents([.year, .month, .day], from: moment)
        let here = calendar(in: reference).dateComponents([.year, .month, .day], from: moment)
        guard let thereDay = Calendar(identifier: .gregorian).date(from: there),
              let hereDay = Calendar(identifier: .gregorian).date(from: here)
        else { return 0 }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: hereDay, to: thereDay).day ?? 0
    }

    private static func calendar(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
}
