import SwiftUI

/// Week numbers both ways: the week of a date, and the days of a week.
struct WeekNumbersView: View {
    @State private var date = Date.now
    @State private var year = Calendar.autoupdatingCurrent.component(.yearForWeekOfYear, from: .now)
    @State private var week = Calendar.autoupdatingCurrent.component(.weekOfYear, from: .now)

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        SideBySideForm {
            Section("Pick a Date") {
                DateRow(title: "Date", date: $date, includesTime: false)
            }
        } trailing: {
            Section {
                ResultHero(color: .teal) {
                    VStack(spacing: 0) {
                        Text("Week")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(DateMath.weekOfYear(date), format: .number)
                            .font(.system(size: 80, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .combine)
                    Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .font(.headline)
                }
                .animation(.snappy, value: date)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("Day of the Year", value: DateMath.dayOfYear(date).formatted())
                LabeledContent("Days Left in the Year", value: daysLeftInYear.formatted())
                LabeledContent("Quarter", value: calendar.component(.quarter, from: date).formatted())
                LabeledContent("Weeks in \(String(yearForWeek))", value: weeksInYear(yearForWeek).formatted())
                LabeledContent("Year Progress") {
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

            Section {
                Stepper(value: $year, in: 1...9999) {
                    LabeledContent("Year", value: String(year))
                }
                Stepper(value: $week, in: 1...weeksInYear(year)) {
                    LabeledContent("Week", value: week.formatted())
                }
                if let interval = weekInterval {
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
            } header: {
                Text("Find a Week")
            } footer: {
                Text("Week numbers follow your region's calendar, which decides the first day of the week and the first week of the year.")
            }
            .onChange(of: year) {
                week = min(week, weeksInYear(year))
            }
        }
        .navigationTitle("Week Number")
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

    private var weekInterval: DateInterval? {
        DateMath.week(week, of: year, calendar: calendar)
    }
}
