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
                    Picker("calc.sleep.planFrom", selection: $mode.animation()) {
                        Text("calc.sleep.wakeUpTime").tag(Mode.wakeUp)
                        Text("common.bedtime").tag(Mode.bedtime)
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .wakeUp:
                        DateRow(title: "calc.sleep.wakeUpAt", date: minutesBinding($wakeUpMinutes), includesDate: false, includesTime: true, showsReset: false)
                    case .bedtime:
                        bedtimeRow(now: now)
                    }
                }

                Section {
                    Stepper(value: $fallAsleepMinutes, in: 0...60, step: 5) {
                        LabeledContent("calc.sleep.timeToFallAsleep", value: minutesText(fallAsleepMinutes))
                    }
                    Stepper(value: $cycleMinutes, in: 70...120, step: 5) {
                        LabeledContent("calc.sleep.sleepCycle", value: minutesText(cycleMinutes))
                    }
                } header: {
                    Text("calc.sleep.yourSleep")
                } footer: {
                    Text("calc.sleep.sleepComesInCyclesOf")
                }
            } trailing: {
                switch mode {
                case .wakeUp: wakeUpPlan(now: now)
                case .bedtime: bedtimePlan(now: now)
                }
            }
        }
        .navigationTitle("common.bedtime")
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
                        Text("calc.sleep.goToBedAt")
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(best.time, format: .dateTime.hour().minute())
                            .scaledFont(size: 64, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("calc.sleep.forOfSleepCycles \(sleepText(best.sleep)) \(best.cycles)")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("calc.sleep.thatsIn \(durationText(best.time.timeIntervalSince(now)))")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                        if best.cycles < bestCycles {
                            Text("calc.sleep.itsTooLateForOf \(sleepText(TimeInterval(bestCycles) * cycleLength))")
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .opacity(0.85)
                        }
                    }
                    .animation(.snappy, value: best)
                } else {
                    ResultHero(color: .nightfall) {
                        Text("calc.sleep.goToBedNow")
                            .scaledFont(size: 40, weight: .heavy, design: .rounded, relativeTo: .title)
                        Text("calc.sleep.notEvenFullCyclesFit \(cycleChoices.last ?? 1) \(wake.formatted(date: .omitted, time: .shortened))")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section("calc.sleep.or") {
            ForEach(options.filter { $0 != best }, id: \.self) { option in
                OptionRow(option: option, sleep: sleepText(option.sleep), hasPassed: option.time <= now)
            }
        }

        reminderSection(wake: wake)
    }

    @ViewBuilder
    private func reminderSection(wake: Date) -> some View {
        Section {
            Toggle("calc.sleep.bedtimeReminder", isOn: $remindsAtBedtime.animation())
            if remindsAtBedtime {
                Picker("calc.sleep.remindMe", selection: $reminderLead) {
                    Text("calc.sleep.atBedtime").tag(0)
                    ForEach([15, 30, 60], id: \.self) { lead in
                        Text("calc.sleep.before \(minutesText(lead))").tag(lead)
                    }
                }
            }
        } footer: {
            if isReminderBlocked {
                #if os(macOS)
                Text("calc.sleep.allowNotificationsForTimityIn.mac")
                #else
                Text("calc.sleep.allowNotificationsForTimityIn")
                #endif
            } else if remindsAtBedtime {
                Text("calc.sleep.everyNightAtForOf \(reminderTimeText) \(sleepText(TimeInterval(bestCycles) * cycleLength)) \(wake.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("calc.sleep.aNudgeEveryNightSo")
            }
        }
    }

    // MARK: Planning from a bedtime

    @ViewBuilder
    private func bedtimeRow(now: Date) -> some View {
        // "Now" goes back to following the clock rather than fixing this minute.
        DateRow(
            title: "calc.sleep.goToBedAt2",
            date: bedtimeBinding(now: now),
            includesDate: false,
            includesTime: true,
            resetToNow: { bedtimeMinutes = nil }
        )
    }

    @ViewBuilder
    private func bedtimePlan(now: Date) -> some View {
        let bedtime = bedtime(now: now)
        let options = SleepCycles.wakeTimes(goingToBedAt: bedtime, cycles: cycleChoices, cycleLength: cycleLength, fallingAsleep: fallingAsleep)
        let best = options.first { $0.cycles == bestCycles } ?? options[0]

        Section {
            ResultHero(color: .nightfall) {
                Text("calc.sleep.wakeUpAt2")
                    .font(.title3.weight(.semibold))
                    .opacity(0.9)
                Text(best.time, format: .dateTime.hour().minute())
                    .scaledFont(size: 64, weight: .heavy, design: .rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("calc.sleep.afterOfSleepCycles \(sleepText(best.sleep)) \(best.cycles)")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .animation(.snappy, value: best)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section("calc.sleep.or") {
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
            ? String(localized: "calc.sleep.goToBedNowTo \(wake)")
            : String(localized: "calc.sleep.bedtimeInToWakeUp \(minutesText(reminderLead)) \(wake)")
        let isScheduled = await bedtimeReminder.schedule(
            minuteOfDay: reminderMinuteOfDay,
            title: String(localized: "calc.sleep.timeForBed"),
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
            Text("calc.sleep.cycles \(option.cycles) \(sleep)")
        } label: {
            HStack(spacing: 6) {
                Text(option.time, format: .dateTime.hour().minute())
                    .font(.title3.weight(.semibold).monospacedDigit())
                if option.isRecommended, !hasPassed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("calc.sleep.recommended")
                }
            }
        }
        .opacity(hasPassed ? 0.45 : 1)
        .accessibilityValue(hasPassed ? Text("calc.sleep.passed") : Text(verbatim: ""))
    }
}
