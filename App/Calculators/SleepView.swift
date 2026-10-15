import SwiftUI

/// When to go to bed to wake up rested, or when to wake up after going to bed at a
/// given time: both fall between sleep cycles. The time to fall asleep and the cycle
/// length are the user's own, and a nightly reminder can say when it's time for bed.
struct SleepView: View {
    enum Mode: Hashable {
        /// From the wake-up time to bedtimes.
        case wakeUp
        /// From a bedtime to wake-up times.
        case bedtime
    }

    let bedtimeReminder: any BedtimeReminding

    @AppStorage("sleepWakeUpMinutes") private var wakeUpMinutes = 7 * 60
    @AppStorage("sleepFallAsleepMinutes") private var fallAsleepMinutes = 15
    @AppStorage("sleepCycleMinutes") private var cycleMinutes = 90
    @AppStorage("sleepRemindsAtBedtime") private var remindsAtBedtime = false
    /// Minutes before bedtime the reminder comes.
    @AppStorage("sleepReminderLead") private var reminderLead = 0

    @State private var mode = Mode.wakeUp
    /// The bedtime to plan from, in minutes after midnight; `nil` for now.
    @State private var bedtimeMinutes: Int?
    @State private var isReminderBlocked = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date

            SideBySideForm {
                Section {
                    Picker("Plan From", selection: $mode.animation()) {
                        Text("Wake-Up Time").tag(Mode.wakeUp)
                        Text("Bedtime").tag(Mode.bedtime)
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .wakeUp:
                        DatePicker("Wake Up At", selection: minutesBinding($wakeUpMinutes), displayedComponents: .hourAndMinute)
                    case .bedtime:
                        bedtimeRow(now: now)
                    }
                }

                Section {
                    Stepper(value: $fallAsleepMinutes, in: 0...60, step: 5) {
                        LabeledContent("Time to Fall Asleep", value: minutesText(fallAsleepMinutes))
                    }
                    Stepper(value: $cycleMinutes, in: 70...120, step: 5) {
                        LabeledContent("Sleep Cycle", value: minutesText(cycleMinutes))
                    }
                } header: {
                    Text("Your Sleep")
                } footer: {
                    Text("Sleep comes in cycles of about 90 minutes, a little shorter or longer for some people. Waking between them feels easier. Most adults need 7 to 9 hours.")
                }
            } trailing: {
                switch mode {
                case .wakeUp: wakeUpPlan(now: now)
                case .bedtime: bedtimePlan(now: now)
                }
            }
        }
        .navigationTitle("Bedtime")
        .task(id: reminderPlan) { await updateReminder() }
    }

    // MARK: Planning from the wake-up time

    @ViewBuilder
    private func wakeUpPlan(now: Date) -> some View {
        let wake = nextTime(wakeUpMinutes, after: now)
        let options = SleepCycles.bedtimes(toWakeAt: wake, cycles: cycleChoices, cycleLength: cycleLength, fallingAsleep: fallingAsleep)
        // The ideal amount of sleep, or once its bedtime has passed, the most sleep still possible.
        let upcoming = options.filter { $0.time > now }
        let best = upcoming.first { $0.cycles == bestCycles } ?? upcoming.first

        Section {
            Group {
                if let best {
                    ResultHero(color: .nightfall) {
                        Text("Go to bed at")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(best.time, format: .dateTime.hour().minute())
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("for \(sleepText(best.sleep)) of sleep · \(best.cycles) cycles")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("That's in \(durationText(best.time.timeIntervalSince(now)))")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                        if best.cycles < bestCycles {
                            Text("It's too late for \(sleepText(TimeInterval(bestCycles) * cycleLength)) of sleep; this is the most still possible.")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .opacity(0.85)
                        }
                    }
                    .animation(.snappy, value: best)
                } else {
                    ResultHero(color: .nightfall) {
                        Text("Go to bed now")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Text("Not even \(cycleChoices.last ?? 1) full cycles fit before \(wake.formatted(date: .omitted, time: .shortened)) any more.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section("Or") {
            ForEach(options.filter { $0 != best }, id: \.self) { option in
                OptionRow(option: option, sleep: sleepText(option.sleep), hasPassed: option.time <= now)
            }
        }

        reminderSection(wake: wake)
    }

    @ViewBuilder
    private func reminderSection(wake: Date) -> some View {
        Section {
            Toggle("Bedtime Reminder", isOn: $remindsAtBedtime.animation())
            if remindsAtBedtime {
                Picker("Remind Me", selection: $reminderLead) {
                    Text("At Bedtime").tag(0)
                    ForEach([15, 30, 60], id: \.self) { lead in
                        Text("\(minutesText(lead)) Before").tag(lead)
                    }
                }
            }
        } footer: {
            if isReminderBlocked {
                Text("Allow notifications for Timity in Settings to get the reminder.")
            } else if remindsAtBedtime {
                Text("Every night at \(reminderTimeText), for \(sleepText(TimeInterval(bestCycles) * cycleLength)) of sleep before \(wake.formatted(date: .omitted, time: .shortened)).")
            } else {
                Text("A nudge every night, so you're in bed in time.")
            }
        }
    }

    // MARK: Planning from a bedtime

    @ViewBuilder
    private func bedtimeRow(now: Date) -> some View {
        HStack(spacing: 12) {
            DatePicker("Go to Bed At", selection: bedtimeBinding(now: now), displayedComponents: .hourAndMinute)
            // Only offered once another time is picked.
            if bedtimeMinutes != nil {
                Button("Now") {
                    withAnimation { bedtimeMinutes = nil }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func bedtimePlan(now: Date) -> some View {
        let bedtime = bedtime(now: now)
        let options = SleepCycles.wakeTimes(goingToBedAt: bedtime, cycles: cycleChoices, cycleLength: cycleLength, fallingAsleep: fallingAsleep)
        let best = options.first { $0.cycles == bestCycles } ?? options[0]

        Section {
            ResultHero(color: .nightfall) {
                Text("Wake up at")
                    .font(.title3.weight(.semibold))
                    .opacity(0.9)
                Text(best.time, format: .dateTime.hour().minute())
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("after \(sleepText(best.sleep)) of sleep · \(best.cycles) cycles")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .animation(.snappy, value: best)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section("Or") {
            ForEach(options.filter { $0 != best }, id: \.self) { option in
                OptionRow(option: option, sleep: sleepText(option.sleep), hasPassed: false)
            }
        }
    }

    /// The picked bedtime, or now; a time up to an hour ago counts as tonight's.
    private func bedtime(now: Date) -> Date {
        guard let bedtimeMinutes else { return now }
        return nextTime(bedtimeMinutes, after: now.addingTimeInterval(-3600))
    }

    private func bedtimeBinding(now: Date) -> Binding<Date> {
        Binding(
            get: { bedtime(now: now) },
            set: { bedtimeMinutes = Self.minuteOfDay($0) }
        )
    }

    // MARK: Reminder

    /// What the reminder depends on, so it's rescheduled whenever any of it changes.
    private struct ReminderPlan: Hashable {
        let isOn: Bool
        let minuteOfDay: Int
        let wakeUpMinutes: Int
    }

    private var reminderPlan: ReminderPlan {
        ReminderPlan(isOn: remindsAtBedtime, minuteOfDay: reminderMinuteOfDay, wakeUpMinutes: wakeUpMinutes)
    }

    /// The ideal bedtime for the wake-up time, less the lead, as minutes after midnight.
    private var reminderMinuteOfDay: Int {
        let before = bestCycles * cycleMinutes + fallAsleepMinutes + reminderLead
        return ((wakeUpMinutes - before) % 1440 + 1440) % 1440
    }

    private var reminderTimeText: String {
        Self.time(ofMinute: reminderMinuteOfDay).formatted(date: .omitted, time: .shortened)
    }

    private func updateReminder() async {
        guard remindsAtBedtime else {
            await bedtimeReminder.cancel()
            return
        }
        let wake = Self.time(ofMinute: wakeUpMinutes).formatted(date: .omitted, time: .shortened)
        let body = reminderLead == 0
            ? String(localized: "Go to bed now to wake up rested at \(wake).")
            : String(localized: "Bedtime in \(minutesText(reminderLead)), to wake up rested at \(wake).")
        let isScheduled = await bedtimeReminder.schedule(
            minuteOfDay: reminderMinuteOfDay,
            title: String(localized: "Time for Bed"),
            body: body
        )
        isReminderBlocked = !isScheduled
        if !isScheduled { remindsAtBedtime = false }
    }

    // MARK: Helpers

    private var cycleLength: TimeInterval { TimeInterval(cycleMinutes) * 60 }
    private var fallingAsleep: TimeInterval { TimeInterval(fallAsleepMinutes) * 60 }
    private var bestCycles: Int { SleepCycles.bestCycles(cycleLength: cycleLength) }

    /// One more cycle than the ideal to two fewer, the most sleep first.
    private var cycleChoices: [Int] {
        Array((max(1, bestCycles - 2)...(bestCycles + 1)).reversed())
    }

    private func minutesBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Self.time(ofMinute: minutes.wrappedValue) },
            set: { minutes.wrappedValue = Self.minuteOfDay($0) }
        )
    }

    /// The next time `minuteOfDay` comes round after `date`.
    private func nextTime(_ minuteOfDay: Int, after date: Date) -> Date {
        Calendar.autoupdatingCurrent.nextDate(
            after: date,
            matching: DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60),
            matchingPolicy: .nextTime
        ) ?? date
    }

    private static func time(ofMinute minuteOfDay: Int) -> Date {
        Calendar.autoupdatingCurrent.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: .now) ?? .now
    }

    private static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// "7 h 30 min".
    private func sleepText(_ sleep: TimeInterval) -> String {
        durationText(sleep)
    }

    private func durationText(_ interval: TimeInterval) -> String {
        Duration.seconds(max(0, interval)).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "15 min".
    private func minutesText(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

private struct OptionRow: View {
    let option: SleepCycles.Option
    let sleep: String
    /// A bedtime that's already gone by tonight.
    let hasPassed: Bool

    var body: some View {
        LabeledContent {
            Text("\(option.cycles) cycles · \(sleep)")
        } label: {
            HStack(spacing: 6) {
                Text(option.time, format: .dateTime.hour().minute())
                    .font(.title3.weight(.semibold).monospacedDigit())
                if option.isRecommended, !hasPassed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Recommended")
                }
            }
        }
        .opacity(hasPassed ? 0.45 : 1)
        .accessibilityValue(hasPassed ? Text("Passed") : Text(verbatim: ""))
    }
}
