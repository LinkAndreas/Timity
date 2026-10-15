import AppIntents
import Foundation

/// "Add a countdown to my trip on 3 May" — creates an event.
struct CreateEventIntent: AppIntent {
    static let title: LocalizedStringResource = "intents.addCountdown"
    static let description = IntentDescription("intents.addsAnEventToCount")

    @Parameter(title: "common.name")
    var name: String

    @Parameter(title: "common.date")
    var date: Date

    @Parameter(title: "intents.repeatsEveryYear", default: false)
    var repeatsYearly: Bool

    /// Off, the event lasts the whole day of the date.
    @Parameter(title: "common.includeTime", default: false)
    var includesTime: Bool

    @Dependency private var repository: any EventRepository

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) on \(\.$date)") {
            \.$repeatsYearly
            \.$includesTime
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<EventEntity> {
        var event = EventSnapshot(title: name, isAllDay: !includesTime, recurrence: repeatsYearly ? .yearly : .never)
        event.setStartDate(date)
        repository.save(event)
        let countdown = event.countdown()
        return .result(
            value: EventEntity(event),
            dialog: "\(name): \(CountdownText.relativeDays(countdown))."
        )
    }
}

/// The days between two dates, for Shortcuts.
struct DaysBetweenIntent: AppIntent {
    static let title: LocalizedStringResource = "intents.daysBetweenDates"
    static let description = IntentDescription("intents.countsTheCalendarDaysFrom")

    @Parameter(title: "common.start")
    var start: Date

    @Parameter(title: "common.end")
    var end: Date

    @Parameter(title: "intents.workingDaysOnly", default: false)
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
    static let title: LocalizedStringResource = "intents.addToDate"
    static let description = IntentDescription("intents.addsMinutesHoursDaysWeeks")

    enum Unit: String, AppEnum {
        case minutes, hours, days, workingDays, weeks, months, years

        static let typeDisplayRepresentation: TypeDisplayRepresentation = "intents.unit"
        static let caseDisplayRepresentations: [Unit: DisplayRepresentation] = [
            .minutes: "common.minutes",
            .hours: "common.hours",
            .days: "intents.days",
            .workingDays: "intents.workingDays",
            .weeks: "intents.weeks",
            .months: "intents.months",
            .years: "intents.years",
        ]
    }

    @Parameter(title: "common.date")
    var date: Date

    @Parameter(title: "intents.amount", default: 1)
    var amount: Int

    @Parameter(title: "intents.unit", default: .days)
    var unit: Unit

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) \(\.$unit) to \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Date> {
        let result: Date?
        switch unit {
        case .minutes: result = DateMath.date(date, movedBy: TimeBreakdown(minutes: amount), backwards: false)
        case .hours: result = DateMath.date(date, movedBy: TimeBreakdown(hours: amount), backwards: false)
        case .days: result = DateMath.date(date, movedBy: TimeBreakdown(days: amount), backwards: false)
        case .weeks: result = DateMath.date(date, movedBy: TimeBreakdown(weeks: amount), backwards: false)
        case .months: result = DateMath.date(date, movedBy: TimeBreakdown(months: amount), backwards: false)
        case .years: result = DateMath.date(date, movedBy: TimeBreakdown(years: amount), backwards: false)
        case .workingDays: result = DateMath.date(date, addingWorkingDays: amount, region: HolidayRegion(locale: .autoupdatingCurrent))
        }
        return .result(value: result ?? date)
    }
}
