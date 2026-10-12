import Foundation

/// A life drawn as one row of 52 weeks per year.
struct LifeInWeeks: Equatable, Sendable {
    static let weeksPerRow = 52

    /// Rows to draw, one per year of life.
    let years: Int
    /// Whole years already lived.
    let completedYears: Int
    /// Weeks lived in the current year, from 0 to 51.
    let weeksIntoYear: Int
    /// Weeks lived in total.
    let weeksLived: Int

    init(birth: Date, now: Date, expectedYears: Int = 90, calendar: Calendar = .autoupdatingCurrent) {
        years = max(1, expectedYears)
        guard birth < now else {
            completedYears = 0
            weeksIntoYear = 0
            weeksLived = 0
            return
        }
        let age = calendar.dateComponents([.year], from: birth, to: now).year ?? 0
        let lastBirthday = calendar.date(byAdding: .year, value: age, to: birth) ?? birth
        completedYears = age
        weeksIntoYear = min(Self.weeksPerRow - 1, DateMath.calendarDays(from: lastBirthday, to: now, calendar: calendar) / 7)
        weeksLived = DateMath.calendarDays(from: birth, to: now, calendar: calendar) / 7
    }

    /// Whether the week at `row` (year of life) and `column` (week of that year) has passed.
    func isLived(row: Int, column: Int) -> Bool {
        row < completedYears || (row == completedYears && column < weeksIntoYear)
    }

    /// Whether it's the current week.
    func isCurrent(row: Int, column: Int) -> Bool {
        row == completedYears && column == weeksIntoYear
    }

    /// How much of the expected life has passed, from 0 to 1.
    var progress: Double {
        min(1, Double(completedYears * Self.weeksPerRow + weeksIntoYear) / Double(years * Self.weeksPerRow))
    }
}
