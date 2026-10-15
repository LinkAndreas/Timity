import SwiftUI

/// How long from one date to another, optionally with times: the days, in years,
/// months and days, and in weeks and hours — or with times, down to the minute.
struct TimeBetweenView: View {
    let showsWeeks: Bool

    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var end = Calendar.autoupdatingCurrent.date(byAdding: .month, value: 1, to: Calendar.autoupdatingCurrent.startOfDay(for: .now)) ?? .now
    @State private var includesTime = false
    @State private var includesLastDay = false

    var body: some View {
        let (from, to) = resolvedDates

        SideBySideForm {
            Section {
                DateRow(title: "common.from", date: $start, includesTime: includesTime)
                DateRow(title: "common.to", date: $end, includesTime: includesTime)
                Toggle("common.includeTime", isOn: timeToggle.animation())
                // With times, the end is a moment, not a whole day.
                if !includesTime {
                    Toggle("calc.timeBetween.includeTheEndDate", isOn: $includesLastDay)
                }
            } footer: {
                if includesTime {
                    Text("calc.timeBetween.countsTheHoursThatReally")
                } else {
                    Text("calc.timeBetween.countsTheEndDateAs")
                }
            }
        } trailing: {
            Section {
                result(from: from, to: to)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("calc.timeBetween.thatsAlso") {
                alsoRows(from: from, to: to)
                    .monospacedDigit()
            }
        }
        .navigationTitle("common.timeBetween")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("calc.timeBetween.swapDates", systemImage: "arrow.up.arrow.down") {
                    withAnimation { swap(&start, &end) }
                }
            }
        }
    }

    private func result(from: Date, to: Date) -> some View {
        let full = DateMath.breakdown(between: from, and: to, includeWeeks: showsWeeks)
        let breakdown = includesTime
            ? TimeBreakdown(years: full.years, months: full.months, weeks: full.weeks, days: full.days, hours: full.hours, minutes: full.minutes)
            : TimeBreakdown(years: full.years, months: full.months, weeks: full.weeks, days: full.days)
        let (value, unit) = headline(from: from, to: to)

        return ResultHero(color: .blue) {
            VStack(spacing: 0) {
                Text(value, format: .number)
                    .scaledFont(size: 72, weight: .heavy, design: .rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(CountdownText.unit(unit, value: value))
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            BreakdownChips(breakdown: breakdown, showsSeconds: false, direction: .past)
        }
        .animation(.snappy, value: value)
    }

    /// The big number: calendar days, or with times whole days that pass — and for
    /// less than a day, hours or minutes.
    private func headline(from: Date, to: Date) -> (Int, TimeUnit) {
        guard includesTime else { return (DateMath.calendarDays(from: from, to: to), .day) }
        let elapsed = Calendar.autoupdatingCurrent.dateComponents([.day, .hour, .minute], from: from, to: to)
        if let days = elapsed.day, days > 0 { return (days, .day) }
        if let hours = elapsed.hour, hours > 0 { return (hours, .hour) }
        return (elapsed.minute ?? 0, .minute)
    }

    @ViewBuilder
    private func alsoRows(from: Date, to: Date) -> some View {
        let totals = DateMath.totals(between: from, and: to)
        let days = includesTime
            ? Calendar.autoupdatingCurrent.dateComponents([.day], from: from, to: to).day ?? 0
            : DateMath.calendarDays(from: from, to: to)
        // Whole weeks and days, as people count them, rather than 4.43 weeks.
        if days >= 7 {
            if days % 7 == 0 {
                Text("\(days / 7) \(CountdownText.unit(.week, value: days / 7))")
            } else {
                Text("calc.timeBetween.and \(days / 7) \(CountdownText.unit(.week, value: days / 7)) \(days % 7) \(CountdownText.unit(.day, value: days % 7))")
            }
        }
        let minutes = Int(totals.minutes.rounded(.down))
        let hours = minutes / 60
        if includesTime, minutes % 60 != 0 {
            Text("calc.timeBetween.and \(hours) \(CountdownText.unit(.hour, value: hours)) \(minutes % 60) \(CountdownText.unit(.minute, value: minutes % 60))")
        } else {
            Text("\(hours.formatted()) \(CountdownText.unit(.hour, value: hours))")
        }
        if includesTime {
            Text("\(minutes.formatted()) \(CountdownText.unit(.minute, value: minutes))")
        }
    }

    /// Turning times on keeps the days and starts both at the current time, so the span
    /// stays the same until a time changes; turning them off goes back to whole days.
    private var timeToggle: Binding<Bool> {
        Binding(
            get: { includesTime },
            set: { includesTime in
                let calendar = Calendar.autoupdatingCurrent
                if includesTime {
                    let now = Date.now
                    start = DateMath.date(start, atTimeOf: now)
                    end = DateMath.date(end, atTimeOf: now)
                } else {
                    start = calendar.startOfDay(for: start)
                    end = calendar.startOfDay(for: end)
                }
                self.includesTime = includesTime
            }
        )
    }

    /// The earlier and the later moment. Without times they're whole days, the later
    /// one moved to the end of its day when the last day counts.
    private var resolvedDates: (Date, Date) {
        let calendar = Calendar.autoupdatingCurrent
        if includesTime {
            return (min(start, end), max(start, end))
        }
        let picked = [start, end].map { calendar.startOfDay(for: $0) }
        let earlier = picked.min()!
        var later = picked.max()!
        if includesLastDay {
            later = calendar.date(byAdding: .day, value: 1, to: later) ?? later
        }
        return (earlier, later)
    }
}
