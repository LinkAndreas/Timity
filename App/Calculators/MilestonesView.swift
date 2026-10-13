import SwiftUI

/// The round numbers ahead since a date: 10,000 days, 1,000 weeks, a billion seconds.
struct MilestonesView: View {
    /// The user's birthday, to start from.
    let birthday: Date?
    /// Keeps a milestone as an event and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    @State private var since = Calendar.autoupdatingCurrent.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var savedCount = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            let upcoming = Milestones.upcoming(since: since, after: context.date, limit: 12)
            let passed = Milestones.all(since: since).filter { $0.date <= context.date }.suffix(3).reversed()

            SideBySideForm {
                Section {
                    DatePicker("Since", selection: $since, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    Text("A birthday, a wedding, the day you quit smoking — any date counts.")
                }
            } trailing: {
                if let next = upcoming.first {
                    Section {
                        ResultHero(color: .ember) {
                            Text("Next milestone")
                                .font(.title3.weight(.semibold))
                                .opacity(0.9)
                            Text(name(next))
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                            Text(next.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                                .font(.headline)
                            Text(CountdownText.relativeDays(Countdown(startDate: next.date, isAllDay: true, recurrence: .never, now: context.date, calendar: .autoupdatingCurrent)))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .glassEffect(.regular, in: .capsule)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Coming Up") {
                    ForEach(upcoming.dropFirst()) { milestone in
                        row(milestone)
                    }
                }

                if !passed.isEmpty {
                    Section("Already Reached") {
                        ForEach(Array(passed)) { milestone in
                            LabeledContent(name(milestone), value: milestone.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Milestones")
        .sensoryFeedback(.success, trigger: savedCount)
        .onAppear { if let birthday { since = birthday } }
    }

    private func row(_ milestone: Milestone) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name(milestone))
                    .font(.headline)
                Text(milestone.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Count Down", systemImage: "calendar.badge.plus") { save(milestone) }
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
        var event = EventSnapshot(title: name(milestone), isAllDay: true, color: .ember, symbolName: "sparkles")
        event.setStartDate(milestone.date)
        onSaveAsEvent(event)
    }
}
