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
