import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// "Add a countdown to my trip on 3 May" — creates an event.
struct CreateEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Countdown"
    static let description = IntentDescription("Adds an event to count down to or since.")

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Date")
    var date: Date

    @Parameter(title: "Repeats Every Year", default: false)
    var repeatsYearly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) on \(\.$date)") {
            \.$repeatsYearly
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<EventEntity> {
        let context = TimityStore.container.mainContext
        let event = Event(title: name, date: date, isAllDay: true, recurrence: repeatsYearly ? .yearly : .never)
        event.setStartDate(date)
        context.insert(event)
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        let countdown = event.snapshot.countdown()
        return .result(
            value: EventEntity(event.snapshot),
            dialog: "\(name): \(CountdownText.relativeDays(countdown))."
        )
    }
}

/// The days between two dates, for Shortcuts.
struct DaysBetweenIntent: AppIntent {
    static let title: LocalizedStringResource = "Days Between Dates"
    static let description = IntentDescription("Counts the calendar days from one date to another.")

    @Parameter(title: "Start")
    var start: Date

    @Parameter(title: "End")
    var end: Date

    @Parameter(title: "Working Days Only", default: false)
    var workingDaysOnly: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Days from \(\.$start) to \(\.$end)") {
            \.$workingDaysOnly
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let days = workingDaysOnly
            ? DateMath.workingDays(between: start, and: end, region: HolidayRegion(locale: .autoupdatingCurrent))
            : abs(DateMath.calendarDays(from: start, to: end))
        return .result(value: days, dialog: "\(days.formatted()) \(CountdownText.unit(.day, value: days))")
    }
}

/// A date moved by an amount, for Shortcuts.
struct AddToDateIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Date"
    static let description = IntentDescription("Adds days, weeks, months or years to a date, or working days.")

    enum Unit: String, AppEnum {
        case days, workingDays, weeks, months, years

        static let typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
        static let caseDisplayRepresentations: [Unit: DisplayRepresentation] = [
            .days: "Days",
            .workingDays: "Working Days",
            .weeks: "Weeks",
            .months: "Months",
            .years: "Years",
        ]
    }

    @Parameter(title: "Date")
    var date: Date

    @Parameter(title: "Amount", default: 1)
    var amount: Int

    @Parameter(title: "Unit", default: .days)
    var unit: Unit

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) \(\.$unit) to \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Date> {
        let result: Date?
        switch unit {
        case .days: result = DateMath.date(date, movedBy: TimeBreakdown(days: amount), backwards: false)
        case .weeks: result = DateMath.date(date, movedBy: TimeBreakdown(weeks: amount), backwards: false)
        case .months: result = DateMath.date(date, movedBy: TimeBreakdown(months: amount), backwards: false)
        case .years: result = DateMath.date(date, movedBy: TimeBreakdown(years: amount), backwards: false)
        case .workingDays: result = DateMath.date(date, addingWorkingDays: amount, region: HolidayRegion(locale: .autoupdatingCurrent))
        }
        return .result(value: result ?? date)
    }
}
