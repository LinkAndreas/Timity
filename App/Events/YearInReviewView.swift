import Charts
import SwiftUI

/// The year in events: how many moments there were, how many have passed, the
/// busiest month, the oldest countdown and the longest streak — shareable as a card.
struct YearInReviewView: View {
    let events: [EventSnapshot]
    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.autoupdatingCurrent.component(.year, from: .now)
    @State private var shareImage: Image?

    var body: some View {
        NavigationStack {
            let stats = EventStatistics(events: events, year: year)

            ScrollView {
                VStack(spacing: 16) {
                    Picker("common.year", selection: $year) {
                        ForEach(years, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)

                    ReviewSummary(stats: stats, year: year, longestStreak: longestStreak)

                    Card(title: "events.momentsPerMonth") {
                        Chart {
                            ForEach(Array(stats.occurrencesPerMonth.enumerated()), id: \.offset) { index, count in
                                BarMark(
                                    x: .value("common.month", Calendar.autoupdatingCurrent.shortMonthSymbols[index]),
                                    y: .value("events.moments", count)
                                )
                                .foregroundStyle(index + 1 == stats.busiestMonth?.month ? Color.accentColor : Color.accentColor.opacity(0.4))
                                .cornerRadius(4)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 3))
                        }
                        .frame(height: 180)
                        .accessibilityLabel(Text("events.momentsPerMonth2"))
                    }

                    if let oldest = stats.oldestEvent {
                        Card(title: "events.longestRunning") {
                            LabeledContent(oldest.title) {
                                Text(oldest.date, format: .shortDate())
                            }
                        }
                    }
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
            .task(id: "\(year)-\(events.count)") {
                let renderer = ImageRenderer(content: ReviewSummary(stats: stats, year: year, longestStreak: longestStreak)
                    .frame(width: 400)
                    .padding(24)
                    .background(Color(.systemBackground)))
                renderer.scale = 3
                shareImage = renderer.cgImage.map { Image(decorative: $0, scale: renderer.scale) }
            }
        }
        .presentationSizing(.form)
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
            AdaptiveStack(horizontalAlignment: .center, spacing: 10) {
                fact(value: stats.reachedInYear.formatted(), label: "events.reached")
                fact(value: stats.totalEvents.formatted(), label: "common.events")
                if let busiest = stats.busiestMonth {
                    fact(value: Calendar.autoupdatingCurrent.shortMonthSymbols[busiest.month - 1], label: "events.busiestMonth")
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

    private func fact(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.horizontal, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
    }
}
