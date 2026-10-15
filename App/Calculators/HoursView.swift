import SwiftUI

/// Adds up durations written the way people write them — for timesheets,
/// recipes and playlists.
struct HoursView: View {
    @State private var entries: [String] = ["1:45", "2:30"]
    @FocusState private var focusedEntry: Int?

    var body: some View {
        SideBySideForm {
            Section {
                ResultHero(color: .orange) {
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(total))
                            .scaledFont(size: 64, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("calc.hours.hours \(HoursMath.decimalHours(total).formatted(.number.precision(.fractionLength(2))))")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
                .animation(.snappy, value: total)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        } trailing: {
            Section {
                ForEach(entries.indices, id: \.self) { index in
                    HStack {
                        TextField("1:45", text: $entries[index])
                            .keyboardType(.numbersAndPunctuation)
                            .monospacedDigit()
                            .focused($focusedEntry, equals: index)
                            .submitLabel(.next)
                            .onSubmit(addEntry)
                        if let seconds = HoursMath.seconds(from: entries[index]) {
                            Text(HoursMath.clockText(seconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else if !entries[index].isEmpty {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                                .accessibilityLabel("calc.hours.cantReadThisDuration")
                        }
                    }
                }
                .onDelete { entries.remove(atOffsets: $0) }
                Button("calc.hours.addDuration", systemImage: "plus", action: addEntry)
            } header: {
                Text("calc.hours.times")
            } footer: {
                Text("calc.hours.type145175")
            }
        }
        .navigationTitle("common.addUpTimes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("calc.hours.clearAll", systemImage: "trash") {
                    withAnimation { entries = [""] }
                    focusedEntry = 0
                }
                .disabled(entries.allSatisfy(\.isEmpty))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var total: TimeInterval {
        entries.compactMap(HoursMath.seconds(from:)).reduce(0, +)
    }

    private func addEntry() {
        entries.append("")
        focusedEntry = entries.count - 1
    }
}

/// The time worked between two clock times less a break, and what it earns.
struct ShiftView: View {
    @State private var start = Calendar.autoupdatingCurrent.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var end = Calendar.autoupdatingCurrent.date(bySettingHour: 17, minute: 30, second: 0, of: .now) ?? .now
    @State private var breakMinutes = 30
    @AppStorage("shiftHourlyRate") private var hourlyRate = 0.0

    private let currency = Locale.autoupdatingCurrent.currency?.identifier ?? "USD"

    var body: some View {
        SideBySideForm {
            Section {
                DatePicker("common.start", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("common.end", selection: $end, displayedComponents: .hourAndMinute)
                Stepper(value: $breakMinutes, in: 0...480, step: 5) {
                    LabeledContent("calc.hours.break", value: HoursMath.clockText(TimeInterval(breakMinutes * 60)))
                }
            } footer: {
                Text("calc.hours.anEndEarlierThanThe")
            }
        } trailing: {
            Section {
                ResultHero(color: .green) {
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(worked))
                            .scaledFont(size: 64, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("calc.hours.hours \(HoursMath.decimalHours(worked).formatted(.number.precision(.fractionLength(2))))")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    if hourlyRate > 0 {
                        Text(HoursMath.decimalHours(worked) * hourlyRate, format: .currency(code: currency))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                            .contentTransition(.numericText())
                    }
                }
                .animation(.snappy, value: worked)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                LabeledContent("calc.hours.payPerHour") {
                    TextField("calc.hours.optional", value: $hourlyRate, format: .currency(code: currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("calc.hours.withAnHourlyRateTimity")
            }
        }
        .navigationTitle("common.workHours")
        .scrollDismissesKeyboard(.interactively)
    }

    private var worked: TimeInterval {
        let calendar = Calendar.autoupdatingCurrent
        let span = HoursMath.span(
            from: calendar.dateComponents([.hour, .minute], from: start),
            to: calendar.dateComponents([.hour, .minute], from: end)
        )
        return max(0, span - TimeInterval(breakMinutes * 60))
    }
}
