import Charts
import SwiftUI

/// The year in events: how many moments there were, how many are behind and still ahead, how
/// that compares with the year before, the busiest month, and each moment by month — the
/// numbers shareable as a card.
struct YearInReviewView: View {
    let events: [EventSnapshot]
    /// Shows an event from the list, the review closed.
    let onOpen: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.autoupdatingCurrent.component(.year, from: .now)
    /// The month picked in the chart (1–12); `nil` lists the whole year.
    @State private var month: Int?
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            let stats = EventStatistics(events: events, year: year)
            let previousYear = EventStatistics(events: events, year: year - 1).occurrencesInYear

            ScrollView {
                VStack(spacing: 16) {
                    Picker("common.year", selection: $year) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)

                    ReviewSummary(stats: stats, year: year, previousYear: previousYear, longestStreak: longestStreak)

                    Card(title: "events.momentsPerMonth") {
                        MonthsChart(perMonth: stats.occurrencesPerMonth, busiestMonth: stats.busiestMonth?.month, selection: $month)
                        Text("events.chooseAMonthToSee")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    YearMoments(
                        moments: stats.moments,
                        events: Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }),
                        month: $month,
                        onOpen: { id in
                            dismiss()
                            onOpen(id)
                        }
                    )
                }
                .padding()
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("common.yearInReview")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("common.yearInReview", image: shareImage))
                    }
                }
            }
            // Another year starts with all its months.
            .onChange(of: year) { month = nil }
            .task(id: "\(year)-\(events.count)") {
                let renderer = ImageRenderer(content: ReviewSummary(stats: stats, year: year, previousYear: previousYear, longestStreak: longestStreak)
                    .frame(width: 400)
                    .padding(24)
                    .background(Color(.systemBackground)))
                renderer.scale = 3
                shareImage = renderer.cgImage.map { Image(decorative: $0, scale: renderer.scale) }
            }
        }
        .presentationSizing(.form)
        .macSheetSize()
    }

    /// This year and the four before it.
    private var years: [Int] {
        let current = Calendar.autoupdatingCurrent.component(.year, from: .now)
        return Array((current - 4...current).reversed())
    }

    /// The longest streak of any counter that was started over.
    private var longestStreak: (title: String, days: Int)? {
        events
            .filter { !$0.resetHistory.isEmpty }
            .map { ($0.title, Streaks(start: $0.startDate(), previousStarts: $0.resetHistory, now: .now).longest) }
            .max { $0.1 < $1.1 }
    }
}

/// The year's numbers on a gradient card, also used as the share picture.
private struct ReviewSummary: View {
    let stats: EventStatistics
    let year: Int
    /// The moments of the year before, to compare with.
    let previousYear: Int
    let longestStreak: (title: String, days: Int)?

    var body: some View {
        VStack(spacing: 14) {
            Text(String(year))
                .font(.title3.weight(.semibold))
                .opacity(0.9)
            VStack(spacing: 0) {
                Text(stats.occurrencesInYear, format: .number)
                    .scaledFont(size: 72, weight: .heavy, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("events.momentsToCount")
                    .font(.headline)
            }
            // Two by two: four in a row left each too narrow for its words.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                YearFact(value: stats.reachedInYear.formatted(), label: "events.behindYou")
                // A past year has nothing ahead.
                if stats.aheadInYear > 0 {
                    YearFact(value: stats.aheadInYear.formatted(), label: "events.stillAhead")
                }
                if let busiest = stats.busiestMonth {
                    YearFact(value: Calendar.autoupdatingCurrent.standaloneMonthSymbols[busiest.month - 1], label: "events.busiestMonth")
                }
                if previousYear > 0 {
                    YearFact(
                        value: (stats.occurrencesInYear - previousYear).formatted(.number.sign(strategy: .always(includingZero: false))),
                        label: "events.versusYear \(String(year - 1))"
                    )
                }
            }
            if let longestStreak, longestStreak.days > 0 {
                Text("events.longestStreak \(longestStreak.days) \(CountdownText.unit(.day, value: longestStreak.days)) \(longestStreak.title)")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            Label("common.timity", systemImage: "hourglass")
                .font(.caption.weight(.semibold))
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.2), Color(red: 0.9, green: 0.3, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 28, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

/// One of the year's numbers, with what it counts below it.
private struct YearFact: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

/// A bar for each month; choosing one lists only its moments, choosing it again the whole year.
private struct MonthsChart: View {
    let perMonth: [Int]
    let busiestMonth: Int?
    @Binding var selection: Int?

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        // Bars by the months' short names, which are distinct; under them the one-letter names,
        // as the short ones didn't fit and broke off.
        let names = calendar.shortMonthSymbols
        Chart {
            ForEach(Array(perMonth.enumerated()), id: \.offset) { index, count in
                BarMark(
                    x: .value("common.month", names[index]),
                    y: .value("events.moments", count)
                )
                .foregroundStyle(index + 1 == (selection ?? busiestMonth) ? Color.accentColor : Color.accentColor.opacity(0.4))
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self), let index = names.firstIndex(of: name) {
                        Text(calendar.veryShortStandaloneMonthSymbols[index])
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onTapGesture { location in
                        guard let plot = proxy.plotFrame else { return }
                        let x = location.x - geometry[plot].origin.x
                        guard let name: String = proxy.value(atX: x), let index = names.firstIndex(of: name) else { return }
                        withAnimation(.snappy) {
                            selection = selection == index + 1 ? nil : index + 1
                        }
                    }
            }
        }
        .frame(height: 180)
        .accessibilityLabel(Text("events.momentsPerMonth2"))
    }
}

/// The year's moments under their months, an event repeating within a month once with how often.
private struct YearMoments: View {
    let moments: [EventStatistics.Moment]
    let events: [UUID: EventSnapshot]
    @Binding var month: Int?
    let onOpen: (UUID) -> Void

    private let calendar = Calendar.autoupdatingCurrent

    /// An event's moments in one month.
    private struct Entry: Identifiable {
        let event: EventSnapshot
        var dates: [Date]
        var id: UUID { event.id }
    }

    var body: some View {
        let now = Date.now
        // The next moment to come, for its tag.
        let next = moments.first { $0.date > now }
        let months = entriesByMonth.filter { month == nil || $0.month == month }

        Card(title: month.map { LocalizedStringKey(calendar.standaloneMonthSymbols[$0 - 1]) } ?? "events.theYearsMoments") {
            if months.isEmpty {
                Text("events.noMomentsInThisTime")
                    .foregroundStyle(.secondary)
            }
            ForEach(months, id: \.month) { group in
                VStack(alignment: .leading, spacing: 10) {
                    // The month's name is the card's title once one is picked.
                    if month == nil {
                        Text(calendar.standaloneMonthSymbols[group.month - 1])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 4)
                    }
                    ForEach(group.entries) { entry in
                        Button { onOpen(entry.event.id) } label: {
                            MomentRow(
                                event: entry.event,
                                dates: entry.dates,
                                isPast: entry.dates.allSatisfy { $0 <= now },
                                isNext: next.map { $0.eventID == entry.event.id && entry.dates.contains($0.date) } ?? false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if month != nil {
                Button("events.showAllMonths") {
                    withAnimation(.snappy) { month = nil }
                }
                .padding(.top, 4)
            }
        }
    }

    private var entriesByMonth: [(month: Int, entries: [Entry])] {
        var groups: [Int: [Entry]] = [:]
        for moment in moments {
            guard let event = events[moment.eventID] else { continue }
            let month = calendar.component(.month, from: moment.date)
            if let index = groups[month]?.firstIndex(where: { $0.id == event.id }) {
                groups[month]?[index].dates.append(moment.date)
            } else {
                groups[month, default: []].append(Entry(event: event, dates: [moment.date]))
            }
        }
        return groups.keys.sorted().map { ($0, groups[$0] ?? []) }
    }
}

/// An event in the year's list: its date, or how often it falls in the month.
private struct MomentRow: View {
    let event: EventSnapshot
    let dates: [Date]
    /// Whether all its times in the month have passed.
    let isPast: Bool
    /// Whether it holds the next moment to come.
    let isNext: Bool

    var body: some View {
        HStack(spacing: 12) {
            EventBadge(symbolName: event.symbolName, color: event.color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Group {
                    if dates.count == 1, let date = dates.first {
                        Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    } else {
                        Text("events.timesCount \(dates.count)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isNext {
                Text("widgets.upNext")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.18), in: .capsule)
                    .foregroundStyle(Color.accentColor)
            } else if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(Text("events.behindYou"))
            }
        }
        .opacity(isPast ? 0.7 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
