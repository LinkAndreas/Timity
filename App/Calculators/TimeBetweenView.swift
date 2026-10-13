import SwiftUI

/// How long from one date to another: the days, in years, months and days, and
/// in weeks, months and hours.
struct TimeBetweenView: View {
    let showsWeeks: Bool

    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: .now)) ?? .now
    @State private var includesLastDay = false

    var body: some View {
        let (from, to) = resolvedDates

        Form {
            Section {
                DateRow(title: "From", date: $start, includesTime: false)
                DateRow(title: "To", date: $end, includesTime: false)
                Toggle("Count the Last Day", isOn: $includesLastDay)
            } footer: {
                Text("Counts both dates as full days, as for holidays or rentals.")
            }

            Section {
                result(from: from, to: to)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("In Total") {
                let totals = DateMath.totals(between: from, and: to)
                ForEach([TimeUnit.week, .month, .hour], id: \.self) { unit in
                    LabeledContent {
                        Text(CountdownText.total(totals.value(of: unit)))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } label: {
                        Text(CountdownText.unit(unit, value: 2).localizedCapitalized)
                    }
                }
            }
        }
        .navigationTitle("Days Between")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Swap Dates", systemImage: "arrow.up.arrow.down") {
                    withAnimation { swap(&start, &end) }
                }
            }
        }
    }

    private func result(from: Date, to: Date) -> some View {
        let breakdown = DateMath.breakdown(between: from, and: to, includeWeeks: showsWeeks)
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
            BreakdownChips(
                breakdown: TimeBreakdown(years: breakdown.years, months: breakdown.months, weeks: breakdown.weeks, days: breakdown.days),
                showsSeconds: false,
                direction: .past
            )
        }
        .animation(.snappy, value: days)
    }

    /// The earlier and the later day, the later one moved to the end of its day
    /// when the last day counts.
    private var resolvedDates: (Date, Date) {
        let calendar = Calendar.autoupdatingCurrent
        let picked = [start, end].map { calendar.startOfDay(for: $0) }
        let earlier = picked.min()!
        var later = picked.max()!
        if includesLastDay {
            later = calendar.date(byAdding: .day, value: 1, to: later) ?? later
        }
        return (earlier, later)
    }
}
