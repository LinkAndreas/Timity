import SwiftUI

/// Ready-made events: a tap fills in the editor, or onboarding adds them directly.
enum EventTemplate: String, CaseIterable, Identifiable {
    case newYearsEve, christmas, payday, nextHoliday, weekend, summer, vacation

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .newYearsEve: "New Year’s Eve"
        case .christmas: "Christmas"
        case .payday: "Payday"
        case .nextHoliday: "Next Public Holiday"
        case .weekend: "Weekend"
        case .summer: "Summer"
        case .vacation: "Vacation"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .newYearsEve: "Every year on 31 December"
        case .christmas: "Every year on 24 December"
        case .payday: "The last working day of every month"
        case .nextHoliday: "The next day off where you live"
        case .weekend: "Every Friday at 17:00"
        case .summer: "The June solstice"
        case .vacation: "Pick the dates of your next trip"
        }
    }

    var symbolName: String {
        switch self {
        case .newYearsEve: "party.popper.fill"
        case .christmas: "gift.fill"
        case .payday: "briefcase.fill"
        case .nextHoliday: "flag.fill"
        case .weekend: "sun.max.fill"
        case .summer: "beach.umbrella.fill"
        case .vacation: "airplane"
        }
    }

    var color: EventColor {
        switch self {
        case .newYearsEve: .purple
        case .christmas: .red
        case .payday: .green
        case .nextHoliday: .orange
        case .weekend: .yellow
        case .summer: .cyan
        case .vacation: .blue
        }
    }

    /// The event's values; `nil` when there's no such date, e.g. no known holidays.
    func draft(now: Date = .now, region: HolidayRegion?, calendar: Calendar = .autoupdatingCurrent) -> EventDraft? {
        var draft = EventDraft()
        draft.title = String(localized: title)
        draft.symbolName = symbolName
        draft.color = color
        draft.isAllDay = true
        let year = calendar.component(.year, from: now)

        switch self {
        case .newYearsEve:
            draft.date = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? now
            draft.recurrence = .yearly
        case .christmas:
            draft.date = calendar.date(from: DateComponents(year: year, month: 12, day: 24)) ?? now
            draft.recurrence = .yearly
        case .payday:
            // This month's last working day starts the repeat.
            let monthEnd = calendar.dateInterval(of: .month, for: now)?.end.addingTimeInterval(-1) ?? now
            var day = calendar.startOfDay(for: monthEnd)
            while calendar.isDateInWeekend(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
            draft.date = day
            draft.recurrence = .monthly
            draft.recurrencePattern = .lastWorkingDay
        case .nextHoliday:
            guard let region, let holiday = HolidayImport.candidates(region: region, from: now, calendar: calendar).first else { return nil }
            draft.title = holiday.title
            draft.date = holiday.date
        case .weekend:
            var components = DateComponents()
            components.weekday = 6
            components.hour = 17
            draft.date = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
            draft.isAllDay = false
            draft.recurrence = .weekly
        case .summer:
            draft.date = Astronomy.next(.juneSolstice, after: now)
        case .vacation:
            draft.date = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now)) ?? now
            draft.showsProgress = true
            draft.progressStart = now
        }
        return draft
    }
}

struct TemplateRow: View {
    let template: EventTemplate
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            EventBadge(symbolName: template.symbolName, color: template.color, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(template.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
