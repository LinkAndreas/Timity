import SwiftUI

/// A baby's due date from the first day of the last period, and how far along
/// the pregnancy is.
struct DueDateView: View {
    /// Keeps the due date as an event and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    @State private var lastPeriod = Calendar.autoupdatingCurrent.date(byAdding: .weekOfYear, value: -8, to: .now) ?? .now
    @State private var savedCount = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            let pregnancy = Pregnancy(lastPeriod: lastPeriod, now: context.date)

            Form {
                Section {
                    DatePicker("Last Period Began", selection: $lastPeriod, in: earliest...Date.now, displayedComponents: .date)
                }

                Section {
                    ResultHero(color: .blossom) {
                        Text("Due on")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(pregnancy.dueDate, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        Text(pregnancy.dueDate, format: .dateTime.weekday(.wide))
                            .font(.headline)
                    }
                    .animation(.snappy, value: pregnancy)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Pregnant For") {
                        Text("\(pregnancy.weeks) \(CountdownText.unit(.week, value: pregnancy.weeks)), \(pregnancy.days) \(CountdownText.unit(.day, value: pregnancy.days))")
                    }
                    LabeledContent("Trimester", value: pregnancy.trimester.formatted())
                    LabeledContent("Days to Go", value: pregnancy.daysToGo.formatted())
                    ProgressView(value: pregnancy.progress) {
                        Text(pregnancy.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .tint(EventColor.blossom.color)
                } footer: {
                    Text("An estimate for a 28-day cycle: 40 weeks from the last period. Only a few babies arrive on the day; your doctor or midwife can tell you more.")
                }

                Section {
                    Button {
                        savedCount += 1
                        var event = EventSnapshot(
                            title: String(localized: "Baby Due"),
                            isAllDay: true,
                            color: .blossom,
                            symbolName: "figure.and.child.holdinghands",
                            showsProgress: true,
                            progressStart: Calendar.autoupdatingCurrent.startOfDay(for: lastPeriod)
                        )
                        event.setStartDate(pregnancy.dueDate)
                        onSaveAsEvent(event)
                    } label: {
                        Label("Count Down to the Due Date", systemImage: "calendar.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle("Due Date")
        .sensoryFeedback(.success, trigger: savedCount)
    }

    private var earliest: Date {
        Calendar.autoupdatingCurrent.date(byAdding: .day, value: -Pregnancy.length - 30, to: .now) ?? .distantPast
    }
}
