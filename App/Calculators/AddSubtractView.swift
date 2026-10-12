import SwiftData
import SwiftUI
import WidgetKit

/// A date moved forwards or backwards by years, months, weeks, days, hours and minutes.
struct AddSubtractView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Navigator.self) private var navigator
    @State private var start = Date.now
    @State private var subtracts = false
    @State private var offset = TimeBreakdown(weeks: 6)
    @State private var savedCount = 0

    var body: some View {
        Form {
            Section {
                DateRow(title: "Start", date: $start, includesTime: true)
                Picker("Operation", selection: $subtracts.animation()) {
                    Label("Add", systemImage: "plus").tag(false)
                    Label("Subtract", systemImage: "minus").tag(true)
                }
                .pickerStyle(.segmented)
            }

            Section {
                AmountField(unit: .year, value: $offset.years)
                AmountField(unit: .month, value: $offset.months)
                AmountField(unit: .week, value: $offset.weeks)
                AmountField(unit: .day, value: $offset.days)
                AmountField(unit: .hour, value: $offset.hours)
                AmountField(unit: .minute, value: $offset.minutes)
            } header: {
                Text(subtracts ? LocalizedStringKey("Subtract") : LocalizedStringKey("Add"))
            } footer: {
                Text("Months and years keep the day where they can: one month after 31 January is the last day of February.")
            }

            if let result {
                Section {
                    ResultHero(color: .purple) {
                        Text(result, format: .dateTime.weekday(.wide))
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(result, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        Text(result, format: .dateTime.hour().minute())
                            .font(.title2.weight(.bold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("Week \(DateMath.weekOfYear(result)) · Day \(DateMath.dayOfYear(result))")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .animation(.snappy, value: result)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    Button("Save as Event", systemImage: "calendar.badge.plus") {
                        save(result)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.glassProminent)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Add & Subtract")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation { offset = TimeBreakdown() }
                }
                .disabled(offset.isZero)
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .scrollDismissesKeyboard(.interactively)
    }

    private var result: Date? {
        DateMath.date(start, movedBy: offset, backwards: subtracts)
    }

    private func save(_ date: Date) {
        let event = Event(title: date.formatted(date: .long, time: .shortened), date: date, symbolName: "calendar")
        modelContext.insert(event)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        savedCount += 1
        navigator.showEvent(event.id)
    }
}

/// A number field for one unit of the offset.
private struct AmountField: View {
    let unit: TimeUnit
    @Binding var value: Int

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                TextField(value: $value, format: .number) {
                    Text(CountdownText.unit(unit, value: 2).localizedCapitalized)
                }
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 120)
                Stepper("", value: $value, in: 0...100_000)
                    .labelsHidden()
            }
        } label: {
            Text(CountdownText.unit(unit, value: value).localizedCapitalized)
        }
        .onChange(of: value) { _, newValue in
            if newValue < 0 { value = 0 }
        }
    }
}
