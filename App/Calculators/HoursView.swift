import SwiftUI

/// Adds up durations written the way people write them — for timesheets,
/// recipes and playlists.
struct HoursView: View {
    /// One typed duration, with an identity of its own, so deleting a row never
    /// leaves a field bound to a position that's gone.
    private struct Entry: Identifiable {
        let id = UUID()
        var text = ""
    }

    @State private var entries = [Entry(text: "1:45"), Entry(text: "2:30")]
    @FocusState private var focusedEntry: UUID?

    var body: some View {
        SideBySideForm {
            Section {
                ForEach($entries) { $entry in
                    TimeEntryRow(text: $entry.text, id: entry.id, focus: $focusedEntry, onSubmit: addEntry) {
                        withAnimation { entries.removeAll { $0.id == entry.id } }
                    }
                }
                .onDelete { entries.remove(atOffsets: $0) }
                Button("calc.hours.addDuration", systemImage: "plus", action: addEntry)
                    .rowButtonStyle()
            } header: {
                Text("calc.hours.times")
            } footer: {
                Text("calc.hours.type145175")
            }
        } trailing: {
            // The total last, after the times that make it up.
            Section {
                ResultHero(color: .orange) {
                    // What the big number is: "12:30" alone reads like a time of day.
                    Text("eventDetail.inTotal")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(total))
                            .scaledFont(size: 64, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("calc.hours.orHours \(HoursMath.decimalHours(total).formatted(.number.precision(.fractionLength(2))))")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
                .animation(.snappy, value: total)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("common.addUpTimes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("calc.hours.clearAll", systemImage: "trash") {
                    let blank = Entry()
                    withAnimation { entries = [blank] }
                    focusedEntry = blank.id
                }
                .disabled(entries.allSatisfy(\.text.isEmpty))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var total: TimeInterval {
        entries.compactMap { HoursMath.seconds(from: $0.text) }.reduce(0, +)
    }

    private func addEntry() {
        let entry = Entry()
        entries.append(entry)
        focusedEntry = entry.id
    }
}

/// One typed duration, with what it reads as. On the Mac a button at its end removes it, shown
/// while the pointer is over the row or it's being typed in, as the Mac has no swipe to delete.
private struct TimeEntryRow: View {
    @Binding var text: String
    let id: UUID
    var focus: FocusState<UUID?>.Binding
    let onSubmit: () -> Void
    let remove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            TextField("1:45", text: $text, prompt: Text("1:45"))
                .labelsHidden()
                .numbersAndPunctuationKeyboard()
                .monospacedDigit()
                .focused(focus, equals: id)
                .submitLabel(.next)
                .onSubmit(onSubmit)
            if let seconds = HoursMath.seconds(from: text) {
                Text(HoursMath.clockText(seconds))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else if !text.isEmpty {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("calc.hours.cantReadThisDuration")
            }
            #if os(macOS)
            Button("common.delete", systemImage: "minus.circle.fill", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(Text("common.delete"))
                // Faded rather than gone, so the row doesn't shift as it shows.
                .opacity(isHovering || focus.wrappedValue == id ? 1 : 0)
                // VoiceOver deletes through the row's own action instead.
                .accessibilityHidden(true)
                .animation(.easeOut(duration: 0.15), value: isHovering)
            #endif
        }
        // The separator runs from the row's edge, not from the value on the right.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .macDeleteMenu(remove)
        #if os(macOS)
        .accessibilityAction(named: Text("common.delete"), remove)
        #endif
    }
}

/// The time worked between two clock times less a break, and what it earns.
struct ShiftView: View {
    @State private var start = Calendar.autoupdatingCurrent.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var end = Calendar.autoupdatingCurrent.date(bySettingHour: 17, minute: 30, second: 0, of: .now) ?? .now
    @State private var breakMinutes = 30
    @AppStorage("shiftHourlyRate") private var hourlyRate = 0.0
    @Environment(\.usesResultColumn) private var usesResultColumn

    private let currency = Locale.autoupdatingCurrent.currency?.identifier ?? "USD"

    var body: some View {
        SideBySideForm {
            Section {
                DateRow(title: "common.start", date: $start, includesDate: false, includesTime: true, showsReset: false)
                DateRow(title: "common.end", date: $end, includesDate: false, includesTime: true, showsReset: false)
                NumberStepperRow(
                    title: "calc.hours.break",
                    value: $breakMinutes,
                    range: 0...480,
                    step: 5,
                    valueText: HoursMath.clockText(TimeInterval(breakMinutes * 60)),
                    unit: NumberStepperRow.minutesUnit
                )
            } footer: {
                Text("calc.hours.anEndEarlierThanThe")
            }
            // With a column for the answer, the rate is asked here with the times; what it earns shows there.
            if usesResultColumn {
                PayRateSection(hourlyRate: $hourlyRate, currency: currency)
            }
        } trailing: {
            Section {
                ResultHero(color: .green) {
                    // What the big number is: "8:30" alone reads like a time of day.
                    Text("calc.hours.worked")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    VStack(spacing: 0) {
                        Text(HoursMath.clockText(worked))
                            .scaledFont(size: 64, weight: .heavy, design: .rounded)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("calc.hours.orHours \(HoursMath.decimalHours(worked).formatted(.number.precision(.fractionLength(2))))")
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

            if !usesResultColumn {
                PayRateSection(hourlyRate: $hourlyRate, currency: currency)
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

/// What an hour of work earns, to show what the time earns. Optional.
private struct PayRateSection: View {
    @Binding var hourlyRate: Double
    let currency: String

    var body: some View {
        Section {
            LabeledContent("calc.hours.payPerHour") {
                // Empty rather than "$0.00" without a rate, so the placeholder shows it's optional.
                TextField("calc.hours.optional", value: Binding(
                    get: { hourlyRate > 0 ? hourlyRate : nil },
                    set: { hourlyRate = max(0, $0 ?? 0) }
                ), format: .currency(code: currency), prompt: Text("calc.hours.optional"))
                    .decimalPadKeyboard()
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    #if os(macOS)
                    // The Mac's own small field, as for the other numbers typed in.
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    #endif
            }
        } footer: {
            Text("calc.hours.withAnHourlyRateTimity")
        }
    }
}
