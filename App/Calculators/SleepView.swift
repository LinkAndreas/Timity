import SwiftUI

/// When to go to bed to wake up rested, and when to wake up after going to bed
/// now: both fall between sleep cycles.
struct SleepView: View {
    @AppStorage("sleepWakeUpMinutes") private var wakeUpMinutes = 7 * 60

    var body: some View {
        TimelineView(.everyMinute) { context in
            let wake = wakeUp(after: context.date)
            let bedtimes = SleepCycles.bedtimes(toWakeAt: wake)

            Form {
                Section {
                    DatePicker("Wake Up At", selection: wakeUpTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    // Five cycles, seven and a half hours, suits most adults.
                    let best = bedtimes[1]
                    ResultHero(color: .nightfall) {
                        Text("Go to bed at")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(best.time, format: .dateTime.hour().minute())
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("for \(sleepText(best)) of sleep")
                            .font(.headline)
                    }
                    .animation(.snappy, value: best)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Or") {
                    ForEach([bedtimes[0], bedtimes[2]], id: \.self) { option in
                        OptionRow(option: option, sleep: sleepText(option))
                    }
                }

                Section {
                    ForEach(SleepCycles.wakeTimes(goingToBedAt: context.date).reversed(), id: \.self) { option in
                        OptionRow(option: option, sleep: sleepText(option))
                    }
                } header: {
                    Text("Going to Bed Now? Wake Up At")
                } footer: {
                    Text("Sleep comes in cycles of about 90 minutes. Waking between them feels easier. The times allow 15 minutes to fall asleep.")
                }
            }
        }
        .navigationTitle("Bedtime")
    }

    /// The wake-up time as a time of day, for the picker.
    private var wakeUpTime: Binding<Date> {
        Binding(
            get: {
                Calendar.autoupdatingCurrent.date(bySettingHour: wakeUpMinutes / 60, minute: wakeUpMinutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
                wakeUpMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
            }
        )
    }

    /// The next time the wake-up time comes round.
    private func wakeUp(after now: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: wakeUpMinutes / 60, minute: wakeUpMinutes % 60),
            matchingPolicy: .nextTime
        ) ?? now
    }

    /// "7 h 30 min".
    private func sleepText(_ option: SleepCycles.Option) -> String {
        Duration.seconds(option.sleep).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

private struct OptionRow: View {
    let option: SleepCycles.Option
    let sleep: String

    var body: some View {
        LabeledContent {
            Text("\(option.cycles) cycles · \(sleep)")
        } label: {
            Text(option.time, format: .dateTime.hour().minute())
                .font(.title3.weight(.semibold).monospacedDigit())
        }
    }
}
