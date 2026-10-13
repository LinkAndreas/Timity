import SwiftUI

/// Adds up durations written the way people write them — for timesheets,
/// recipes and playlists.
struct HoursView: View {
    @State private var entries: [String] = ["1:45", "2:30"]
    @FocusState private var focusedEntry: Int?

    var body: some View {
        Form {
            Section {
                ResultHero(color: .orange) {
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(total))
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("\(HoursMath.decimalHours(total).formatted(.number.precision(.fractionLength(2)))) hours")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
                .animation(.snappy, value: total)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

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
                                .accessibilityLabel("Can't read this duration")
                        }
                    }
                }
                .onDelete { entries.remove(atOffsets: $0) }
                Button("Add Duration", systemImage: "plus", action: addEntry)
            } header: {
                Text("Times")
            } footer: {
                Text("Type 1:45, 1.75 or 1h 45m. Start with a minus to take time away.")
            }
        }
        .navigationTitle("Add Up Times")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All", systemImage: "trash") {
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
        Form {
            Section {
                DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                Stepper(value: $breakMinutes, in: 0...480, step: 5) {
                    LabeledContent("Break", value: HoursMath.clockText(TimeInterval(breakMinutes * 60)))
                }
            } footer: {
                Text("An end earlier than the start is the next day, as for night shifts.")
            }

            Section {
                ResultHero(color: .green) {
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(worked))
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("\(HoursMath.decimalHours(worked).formatted(.number.precision(.fractionLength(2)))) hours")
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
                LabeledContent("Pay per Hour") {
                    TextField("Optional", value: $hourlyRate, format: .currency(code: currency))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("With an hourly rate, Timity shows what the time earns.")
            }
        }
        .navigationTitle("Work Hours")
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
