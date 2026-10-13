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

        SideBySideForm {
            Section {
                DateRow(title: "From", date: $start, includesTime: false)
                DateRow(title: "To", date: $end, includesTime: false)
                Toggle("Include the End Date", isOn: $includesLastDay)
            } footer: {
                Text("Counts the end date as a full day too, as for a holiday from Monday to Friday.")
            }
        } trailing: {
            Section {
                result(from: from, to: to)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("That's Also") {
                // Whole weeks and days, as people count them, rather than 4.43 weeks.
                let days = DateMath.calendarDays(from: from, to: to)
                Group {
                    if days % 7 == 0 {
                        Text("\(days / 7) \(CountdownText.unit(.week, value: days / 7))")
                    } else {
                        Text("\(days / 7) \(CountdownText.unit(.week, value: days / 7)) and \(days % 7) \(CountdownText.unit(.day, value: days % 7))")
                    }
                }
                .monospacedDigit()
                let hours = Int(DateMath.totals(between: from, and: to).value(of: .hour))
                Text("\(hours.formatted()) \(CountdownText.unit(.hour, value: hours))")
                    .monospacedDigit()
            }
        }
        .navigationTitle("Count Days")
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
