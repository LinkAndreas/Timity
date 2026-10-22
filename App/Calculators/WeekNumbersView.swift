import SwiftUI

/// Week numbers both ways: the week of a date, and the days of a week.
struct WeekNumbersView: View {
    @State private var date = Date.now
    @State private var year = Calendar.autoupdatingCurrent.component(.yearForWeekOfYear, from: .now)
    @State private var week = Calendar.autoupdatingCurrent.component(.weekOfYear, from: .now)

    @Environment(\.usesResultColumn) private var usesResultColumn

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        SideBySideForm {
            Section("calc.weekNumbers.pickADate") {
                DateRow(title: "common.date", date: $date, includesTime: false)
            }
            // With a column for the answer, the second question is asked here and its seven days
            // are shown there, below the first answer.
            if usesResultColumn {
                FindAWeekSection(year: $year, week: $week, showsDays: false)
            }
        } trailing: {
            Section {
                ResultHero(color: .teal) {
                    VStack(spacing: 0) {
                        // The week of the year, which a bare "Week" didn't say.
                        Text("calc.weekNumbers.calendarWeek")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(DateMath.weekOfYear(date), format: .number)
                            .scaledFont(size: 80, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                    Text(date, format: .fullDate())
                        .font(.headline)
                }
                .animation(.snappy, value: date)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("common.dayOfTheYear", value: DateMath.dayOfYear(date).formatted())
                LabeledContent("calc.weekNumbers.daysLeftInTheYear", value: daysLeftInYear.formatted())
                LabeledContent("calc.weekNumbers.quarter", value: calendar.component(.quarter, from: date).formatted())
                LabeledContent("calc.weekNumbers.weeksIn \(String(yearForWeek))", value: weeksInYear(yearForWeek).formatted())
                LabeledContent("calc.weekNumbers.yearProgress") {
                    Gauge(value: DateMath.progressThroughYear(date)) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(DateMath.progressThroughYear(date), format: .percent.precision(.fractionLength(0)))
                    }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(.teal)
                    .frame(maxWidth: 160)
                }
            }

            if usesResultColumn {
                WeekDaysSection(year: year, week: week)
            } else {
                FindAWeekSection(year: $year, week: $week, showsDays: true)
            }
        }
        .navigationTitle("common.weekNumber")
    }

    private var yearForWeek: Int {
        calendar.component(.yearForWeekOfYear, from: date)
    }

    private var daysLeftInYear: Int {
        guard let end = calendar.dateInterval(of: .year, for: date)?.end else { return 0 }
        return DateMath.calendarDays(from: date, to: end, calendar: calendar) - 1
    }

    private func weeksInYear(_ year: Int) -> Int {
        DateMath.weeksInYear(year, calendar: calendar)
    }
}

/// The days of a week, from its year and number.
/// A week from its year and number, and, where the answer has no column of its own, its seven days.
private struct FindAWeekSection: View {
    @Binding var year: Int
    @Binding var week: Int
    let showsDays: Bool

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        Section {
            NumberStepperRow(title: "common.year", value: $year, range: 1...9999, valueText: String(year))
            NumberStepperRow(title: "common.week2", value: $week, range: 1...DateMath.weeksInYear(year, calendar: calendar), valueText: week.formatted())
            if showsDays {
                WeekDays(year: year, week: week)
            }
        } header: {
            Text("calc.weekNumbers.findAWeek")
        } footer: {
            Text("calc.weekNumbers.weekNumbersFollowYourRegions")
        }
        .onChange(of: year) {
            week = min(week, DateMath.weeksInYear(year, calendar: calendar))
        }
    }
}

/// The seven days of the week asked for, as the answer in the window's last column.
private struct WeekDaysSection: View {
    let year: Int
    let week: Int

    var body: some View {
        Section {
            WeekDays(year: year, week: week)
        } header: {
            Text("common.week \(week.formatted())")
        }
    }
}

/// A week's days, each with its date; the weekend's days quieter.
private struct WeekDays: View {
    let year: Int
    let week: Int

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        if let interval = DateMath.week(week, of: year, calendar: calendar) {
            ForEach(0..<7, id: \.self) { offset in
                if let day = calendar.date(byAdding: .day, value: offset, to: interval.start) {
                    LabeledContent {
                        Text(day, format: .dateTime.day().month(.wide).year())
                    } label: {
                        Text(day, format: .dateTime.weekday(.wide))
                            .foregroundStyle(calendar.isDateInWeekend(day) ? .secondary : .primary)
                    }
                }
            }
        }
    }
}
