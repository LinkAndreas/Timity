import SwiftUI

/// The span between two dates, in calendar units and in totals, with working days.
struct TimeBetweenView: View {
    @Environment(AppSettings.self) private var settings
    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: .now)) ?? .now
    @State private var endsNow = false
    @State private var includesTime = false
    @State private var includesLastDay = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: endsNow ? 1 : 3600)) { context in
            let (from, to) = resolvedDates(now: context.date)

            Form {
                Section {
                    DateRow(title: "Start", date: $start, includesTime: includesTime)
                    if !endsNow {
                        DateRow(title: "End", date: $end, includesTime: includesTime)
                    }
                    Toggle("End Now", isOn: $endsNow.animation())
                    Toggle("Include Time", isOn: $includesTime.animation())
                    Toggle("Count the Last Day", isOn: $includesLastDay)
                } footer: {
                    Text("Counting the last day treats both dates as full days, as for holidays or rentals.")
                }

                Section {
                    result(from: from, to: to)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Total Time") {
                    let totals = DateMath.totals(between: from, and: to)
                    ForEach([TimeUnit.year, .month, .week, .day, .hour, .minute], id: \.self) { unit in
                        LabeledContent {
                            Text(CountdownText.total(totals.value(of: unit)))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } label: {
                            Text(CountdownText.unit(unit, value: 2).localizedCapitalized)
                        }
                    }
                }

                Section {
                    LabeledContent("Working Days") {
                        Text(DateMath.weekdays(between: from, and: to), format: .number)
                            .monospacedDigit()
                    }
                    LabeledContent("Weekend Days") {
                        Text(weekendDays(from: from, to: to), format: .number)
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Weekends follow your region's calendar. Public holidays are counted as working days.")
                }
            }
        }
        .navigationTitle("Time Between")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Swap Dates", systemImage: "arrow.up.arrow.down") {
                    withAnimation { swap(&start, &end) }
                }
                .disabled(endsNow)
            }
        }
    }

    private func result(from: Date, to: Date) -> some View {
        let breakdown = DateMath.breakdown(between: from, and: to, includeWeeks: settings.showsWeeks)
        let days = DateMath.calendarDays(from: from, to: to)

        return ResultHero(color: .blue) {
            VStack(spacing: 0) {
                Text(days, format: .number)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(CountdownText.unit(.day, value: days))
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            if includesTime || endsNow {
                BreakdownChips(breakdown: breakdown, showsSeconds: endsNow && settings.showsSeconds, direction: .past)
            } else {
                BreakdownChips(breakdown: breakdown.dateOnly, showsSeconds: false, direction: .past)
            }
        }
        .animation(.snappy, value: days)
    }

    /// The earlier and the later date, with times dropped unless included, and the
    /// later one moved to the end of its day when the last day counts.
    private func resolvedDates(now: Date) -> (Date, Date) {
        let calendar = Calendar.autoupdatingCurrent
        let picked = [start, endsNow ? now : end].map { includesTime ? $0 : calendar.startOfDay(for: $0) }
        let earlier = picked.min()!
        var later = picked.max()!
        if includesLastDay {
            later = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: later)) ?? later
        }
        return (earlier, later)
    }

    private func weekendDays(from: Date, to: Date) -> Int {
        max(0, DateMath.calendarDays(from: from, to: to) - DateMath.weekdays(between: from, and: to))
    }
}

private extension TimeBreakdown {
    /// Without the time of day, for spans between whole days.
    var dateOnly: TimeBreakdown {
        TimeBreakdown(years: years, months: months, weeks: weeks, days: days)
    }
}
