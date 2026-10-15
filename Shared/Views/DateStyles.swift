import Foundation

/// The two ways Timity writes a date, so the same kind of place reads alike everywhere.
nonisolated extension FormatStyle where Self == Date.FormatStyle {
    /// "Thursday, 5 November 2026": a date that stands on its own, like a result or a heading.
    static func fullDate(withTime: Bool = false, in timeZone: TimeZone = .autoupdatingCurrent) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).year()
        if withTime { style = style.hour().minute() }
        style.timeZone = timeZone
        return style
    }

    /// "Thu, 5 Nov 2026": a date in a list, a row or under a name.
    static func shortDate(withTime: Bool = false, in timeZone: TimeZone = .autoupdatingCurrent) -> Date.FormatStyle {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()
        if withTime { style = style.hour().minute() }
        style.timeZone = timeZone
        return style
    }
}

/// Spans of time as the locale writes them, saying what both ends share once:
/// "15:00–17:00 Uhr", "3:00 – 5:00 PM", "Thu 24 – Sun 27 Dec".
nonisolated extension Date.IntervalFormatStyle {
    /// "15:00 – 17:00" in `timeZone`.
    static func timeRange(in timeZone: TimeZone) -> Self {
        Self(date: .omitted, time: .shortened, timeZone: timeZone)
    }

    /// The span from `start` to `end`; one running backwards is written end to end.
    func string(from start: Date, to end: Date) -> String {
        start <= end
            ? (start..<end).formatted(self)
            : "\((start..<start).formatted(self)) – \((end..<end).formatted(self))"
    }
}
