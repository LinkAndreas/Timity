import SwiftUI

/// The round numbers ahead since a date: 10,000 days, 1,000 weeks, a billion seconds.
struct MilestonesView: View {
    /// The user's birthday, to start from.
    let birthday: Date?
    /// Keeps a milestone as an event and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    @State private var since = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var includesTime = false

    /// The start as counted: the start of its day unless a time is given, which
    /// moves the hour, minute and second milestones to the moment they're reached.
    private var counted: Date {
        includesTime ? since : Calendar.autoupdatingCurrent.startOfDay(for: since)
    }
    @State private var savedCount = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            let upcoming = Milestones.upcoming(since: counted, after: context.date, limit: 12)
            let passed = Milestones.all(since: counted).filter { $0.date <= context.date }.suffix(3).reversed()

            SideBySideForm {
                Section {
                    DateRow(title: "calc.milestones.since", date: $since, includesTime: includesTime, range: Date.distantPast...Date.now, showsReset: false)
                    Toggle("common.includeTime", isOn: $includesTime.animation())
                } footer: {
                    Text("calc.milestones.aBirthdayAWeddingThe")
                }
            } trailing: {
                if let next = upcoming.first {
                    Section {
                        ResultHero(color: .ember) {
                            Text("calc.milestones.nextMilestone")
                                .font(.title3.weight(.semibold))
                                .opacity(0.9)
                            Text(name(next))
                                .scaledFont(size: 40, weight: .heavy, design: .rounded, relativeTo: .title)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                            Text(next.date, format: .fullDate(withTime: includesTime))
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text(CountdownText.relativeDays(Countdown(startDate: next.date, isAllDay: !includesTime, recurrence: .never, now: context.date, calendar: .autoupdatingCurrent)))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(.regular, in: .capsule)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section("calc.milestones.comingUp") {
                    ForEach(upcoming.dropFirst()) { milestone in
                        row(milestone)
                    }
                }

                if !passed.isEmpty {
                    Section("calc.milestones.alreadyReached") {
                        ForEach(Array(passed)) { milestone in
                            LabeledContent(name(milestone), value: milestone.date.formatted(.shortDate(withTime: includesTime)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("common.milestones")
        .sensoryFeedback(.success, trigger: savedCount)
        .onAppear { if let birthday { since = birthday } }
    }

    private func row(_ milestone: Milestone) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name(milestone))
                    .font(.headline)
                Text(milestone.date, format: .shortDate(withTime: includesTime))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("calc.milestones.countDown", systemImage: "calendar.badge.plus") { save(milestone) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
    }

    /// "10,000 days".
    private func name(_ milestone: Milestone) -> String {
        let count = Int(clamping: milestone.value)
        return "\(milestone.value.formatted()) \(CountdownText.unit(milestone.unit, value: count))"
    }

    private func save(_ milestone: Milestone) {
        savedCount += 1
        var event = EventSnapshot(title: name(milestone), isAllDay: !includesTime, color: .ember, symbolName: "sparkles")
        event.setStartDate(milestone.date)
        onSaveAsEvent(event)
    }
}
