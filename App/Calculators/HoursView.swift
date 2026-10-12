import SwiftUI

/// Adds up durations, measures the time between two clock times, and converts
/// between hours and minutes and decimal hours — for timesheets and shifts.
struct HoursView: View {
    @State private var entries: [String] = ["1:45", "2:30"]
    @State private var shiftStart = Calendar.autoupdatingCurrent.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now
    @State private var shiftEnd = Calendar.autoupdatingCurrent.date(bySettingHour: 6, minute: 0, second: 0, of: .now) ?? .now
    @State private var breakMinutes = 30
    @FocusState private var focusedEntry: Int?

    var body: some View {
        Form {
            Section {
                ForEach(entries.indices, id: \.self) { index in
                    HStack {
                        TextField("1:45", text: $entries[index])
                            .keyboardType(.numbersAndPunctuation)
                            .monospacedDigit()
                            .focused($focusedEntry, equals: index)
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
                Button("Add Duration", systemImage: "plus") {
                    entries.append("")
                    focusedEntry = entries.count - 1
                }
            } header: {
                Text("Durations")
            } footer: {
                Text("Write 1:45, 1.75 or 1h 45m. Start with a minus to subtract.")
            }

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
                DatePicker("From", selection: $shiftStart, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: $shiftEnd, displayedComponents: .hourAndMinute)
                Stepper(value: $breakMinutes, in: 0...480, step: 5) {
                    LabeledContent("Break", value: HoursMath.clockText(TimeInterval(breakMinutes * 60)))
                }
                LabeledContent("Worked") {
                    Text("\(HoursMath.clockText(shiftLength)) · \(HoursMath.decimalHours(shiftLength).formatted(.number.precision(.fractionLength(2))))")
                        .font(.body.weight(.semibold).monospacedDigit())
                }
            } header: {
                Text("Between Two Times")
            } footer: {
                Text("An end earlier than the start is the next day, as for night shifts.")
            }
        }
        .navigationTitle("Hours")
        .scrollDismissesKeyboard(.interactively)
    }

    private var total: TimeInterval {
        entries.compactMap(HoursMath.seconds(from:)).reduce(0, +)
    }

    private var shiftLength: TimeInterval {
        let calendar = Calendar.autoupdatingCurrent
        let span = HoursMath.span(
            from: calendar.dateComponents([.hour, .minute], from: shiftStart),
            to: calendar.dateComponents([.hour, .minute], from: shiftEnd)
        )
        return max(0, span - TimeInterval(breakMinutes * 60))
    }
}
