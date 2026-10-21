import SwiftUI

/// Working days, leaving out weekends and public holidays: how many there are
/// between two dates, or which date a number of them leads to — for deadlines,
/// notice periods and deliveries.
struct WorkingDaysView: View {
    enum Question: Hashable {
        case between, deadline
    }

    /// Whose public holidays are left out.
    @Binding var holidayRegion: HolidayRegion?

    @State private var question = Question.between
    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: .now)) ?? .now
    @State private var count = 10

    var body: some View {
        SideBySideForm {
            Section {
                Picker("calc.workingDays.question", selection: $question.animation()) {
                    Text("calc.workingDays.countWorkdays").tag(Question.between)
                    Text("calc.workingDays.findADeadline").tag(Question.deadline)
                }
                .pickerStyle(.segmented)
                // The segments say it; the Mac would squeeze the label in beside them.
                .labelsHidden()
                // Across the whole row, each segment as wide as the others, as the Mac would otherwise
                // set it at the row's start, each segment as wide as its title.
                .buttonSizing(.flexible)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                DateRow(title: "common.from", date: $start, includesTime: false, showsTip: true)
                switch question {
                case .between:
                    DateRow(title: "common.to", date: $end, includesTime: false)
                case .deadline:
                    Stepper(value: $count, in: 1...1000) {
                        LabeledContent("common.workdays") {
                            TextField("common.workdays", value: $count, format: .number)
                                .labelsHidden()
                                .numberPadKeyboard()
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .frame(maxWidth: 70)
                        }
                    }
                }
            }
        } trailing: {
            Section {
                Group {
                    switch question {
                    case .between:
                        let (from, to) = ordered
                        WorkdaysCountResult(days: DateMath.workingDays(between: from, and: to, region: holidayRegion))
                    case .deadline:
                        if let date = DateMath.date(start, addingWorkingDays: max(1, count), region: holidayRegion) {
                            WorkdaysDeadlineResult(start: start, date: date)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if question == .between {
                Section {
                    let (from, to) = ordered
                    LabeledContent("calc.workingDays.weekendDays", value: (DateMath.calendarDays(from: from, to: to) - DateMath.weekdays(between: from, and: to)).formatted())
                    if let holidayRegion {
                        LabeledContent("calc.workingDays.publicHolidays", value: (DateMath.weekdays(between: from, and: to) - DateMath.workingDays(between: from, and: to, region: holidayRegion)).formatted())
                    }
                }
            }

            Section {
                Picker("calc.workingDays.skipPublicHolidaysIn", selection: $holidayRegion) {
                    Text("common.none").tag(HolidayRegion?.none)
                    ForEach(HolidayRegion.allCases) { region in
                        Text(region.localizedName()).tag(Optional(region))
                    }
                }
            } footer: {
                Text(question == .between
                    ? "calc.workingDays.weekendsAndNationwidePublicHolidays"
                    : "calc.workingDays.countingStartsOnTheNext")
            }
        }
        .navigationTitle("common.workdays")
        .scrollDismissesKeyboard(.interactively)
    }

    private var ordered: (Date, Date) {
        (min(start, end), max(start, end))
    }
}

/// How many workdays fall between the two dates.
private struct WorkdaysCountResult: View {
    let days: Int

    var body: some View {
        ResultHero(color: .brown) {
            VStack(spacing: 0) {
                Text(days, format: .number)
                    .scaledFont(size: 72, weight: .heavy, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("calc.workingDays.workdays")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
        }
        .animation(.snappy, value: days)
    }
}

/// The day the workdays end, and how many calendar days away it is.
private struct WorkdaysDeadlineResult: View {
    let start: Date
    let date: Date

    var body: some View {
        ResultHero(color: .brown) {
            Text(date, format: .dateTime.weekday(.wide))
                .font(.title3.weight(.semibold))
                .opacity(0.9)
            Text(date, format: .dateTime.day().month(.wide).year())
                .scaledFont(size: 34, weight: .heavy, design: .rounded, relativeTo: .title)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text("calc.workingDays.calendarDays \(DateMath.calendarDays(from: start, to: date).formatted())")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
        }
        .animation(.snappy, value: date)
    }
}
