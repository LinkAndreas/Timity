import SwiftUI

/// A date moved forwards or backwards by years, months, weeks, days, hours and
/// minutes — or by working days, for deadlines and notice periods.
///
/// Built for quick entry: empty fields instead of zeros, Next and Previous above
/// the keyboard, arrow keys to step a value, and the result shown live above the
/// keyboard while typing.
struct AddSubtractView: View {
    /// The fields, in the order Next moves through them.
    enum Field: Hashable, CaseIterable {
        case years, months, weeks, days, hours, minutes, workingDays

        var unit: TimeUnit {
            switch self {
            case .years: .year
            case .months: .month
            case .weeks: .week
            case .days, .workingDays: .day
            case .hours: .hour
            case .minutes: .minute
            }
        }
    }

    /// Whose public holidays working days leave out.
    @Binding var holidayRegion: HolidayRegion?
    /// Keeps the result as an event and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    @State private var start = Date.now
    @State private var subtracts = false
    @State private var countsWorkingDays = false
    @State private var offset = TimeBreakdown(weeks: 6)
    @State private var workingDays = 10
    @State private var savedCount = 0
    @FocusState private var focus: Field?

    var body: some View {
        Form {
            Section {
                DateRow(title: "Start", date: $start, includesTime: true)
                Picker("Operation", selection: $subtracts.animation()) {
                    Label("Add", systemImage: "plus").tag(false)
                    Label("Subtract", systemImage: "minus").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Count", selection: $countsWorkingDays.animation()) {
                    Text("Calendar Time").tag(false)
                    Text("Working Days").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if countsWorkingDays {
                Section {
                    AmountField(field: .workingDays, value: $workingDays, focus: $focus, onSubmit: moveToNextField)
                    Picker("Public Holidays In", selection: $holidayRegion) {
                        Text("None").tag(HolidayRegion?.none)
                        ForEach(HolidayRegion.allCases) { region in
                            Text(region.localizedName()).tag(Optional(region))
                        }
                    }
                } header: {
                    Text(subtracts ? LocalizedStringKey("Subtract") : LocalizedStringKey("Add"))
                } footer: {
                    Text("Skips weekends and nationwide public holidays. A start on a day off counts from the next working day.")
                }
            } else {
                Section {
                    AmountField(field: .years, value: $offset.years, focus: $focus, onSubmit: moveToNextField)
                    AmountField(field: .months, value: $offset.months, focus: $focus, onSubmit: moveToNextField)
                    AmountField(field: .weeks, value: $offset.weeks, focus: $focus, onSubmit: moveToNextField)
                    AmountField(field: .days, value: $offset.days, focus: $focus, onSubmit: moveToNextField)
                    AmountField(field: .hours, value: $offset.hours, focus: $focus, onSubmit: moveToNextField)
                    AmountField(field: .minutes, value: $offset.minutes, focus: $focus, onSubmit: moveToNextField)
                } header: {
                    Text(subtracts ? LocalizedStringKey("Subtract") : LocalizedStringKey("Add"))
                } footer: {
                    Text("Months and years keep the day where they can: one month after 31 January is the last day of February.")
                }
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
                    Button {
                        save(result)
                    } label: {
                        // The frame inside the label, so the glass spans the row.
                        Label("Save as Event", systemImage: "calendar.badge.plus")
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
        .navigationTitle("Add & Subtract")
        // While typing, the result stays in sight just above the keyboard.
        .safeAreaInset(edge: .bottom) {
            if focus != nil, let result {
                LiveResultBar(result: result)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: focus)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation {
                        offset = TimeBreakdown()
                        workingDays = 0
                    }
                }
                .disabled(countsWorkingDays ? workingDays == 0 : offset.isZero)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous Field", systemImage: "chevron.up") { moveFocus(by: -1) }
                    .disabled(fieldIndex(focus) == 0)
                Button("Next Field", systemImage: "chevron.down") { moveFocus(by: 1) }
                    .disabled(fieldIndex(focus) == visibleFields.count - 1)
                Spacer()
                Button("Clear") { clearFocusedField() }
                Button("Done") { focus = nil }
                    .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Fields and focus

    private var visibleFields: [Field] {
        countsWorkingDays ? [.workingDays] : [.years, .months, .weeks, .days, .hours, .minutes]
    }

    private func fieldIndex(_ field: Field?) -> Int? {
        field.flatMap { visibleFields.firstIndex(of: $0) }
    }

    private func moveFocus(by step: Int) {
        guard let index = fieldIndex(focus) else { return }
        let next = index + step
        guard visibleFields.indices.contains(next) else { return }
        focus = visibleFields[next]
    }

    /// Return moves on; on the last field it closes the keyboard.
    private func moveToNextField() {
        if let index = fieldIndex(focus), index + 1 < visibleFields.count {
            focus = visibleFields[index + 1]
        } else {
            focus = nil
        }
    }

    private func clearFocusedField() {
        switch focus {
        case .years: offset.years = 0
        case .months: offset.months = 0
        case .weeks: offset.weeks = 0
        case .days: offset.days = 0
        case .hours: offset.hours = 0
        case .minutes: offset.minutes = 0
        case .workingDays: workingDays = 0
        case nil: break
        }
    }

    // MARK: Result

    private var result: Date? {
        if countsWorkingDays {
            return DateMath.date(start, addingWorkingDays: subtracts ? -max(0, workingDays) : max(0, workingDays), region: holidayRegion)
        }
        return DateMath.date(start, movedBy: offset, backwards: subtracts)
    }

    private func save(_ date: Date) {
        savedCount += 1
        onSaveAsEvent(EventSnapshot(title: date.formatted(date: .long, time: .shortened), date: date, symbolName: "calendar"))
    }
}

/// One amount: a number field that's empty at zero, with a stepper beside it.
/// Tapping anywhere in the row starts typing; arrow keys step the value.
private struct AmountField: View {
    let field: AddSubtractView.Field
    @Binding var value: Int
    var focus: FocusState<AddSubtractView.Field?>.Binding
    let onSubmit: () -> Void

    private static let range = 0...100_000

    var body: some View {
        HStack(spacing: 12) {
            Text(field == .workingDays
                 ? String(localized: "Working Days")
                 : CountdownText.unit(field.unit, value: value == 1 ? 1 : 2).localizedCapitalized)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(CountdownText.unit(field.unit, value: 2).localizedCapitalized, value: text, format: .number, prompt: Text(verbatim: "0"))
            .keyboardType(.numberPad)
            .submitLabel(.next)
            .multilineTextAlignment(.trailing)
            .font(.body.monospacedDigit().weight(value == 0 ? .regular : .semibold))
            .frame(minWidth: 56, maxWidth: 110)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.fill.tertiary, in: .rect(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(focus.wrappedValue == field ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .focused(focus, equals: field)
            .onSubmit(onSubmit)
            .onKeyPress(.upArrow) {
                step(by: 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                step(by: -1)
                return .handled
            }

            Stepper("", value: $value, in: Self.range)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = field }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            step(by: direction == .increment ? 1 : -1)
        }
    }

    /// The field's text: empty instead of 0, so typing replaces nothing.
    private var text: Binding<Int?> {
        Binding(
            get: { value == 0 ? nil : value },
            set: { value = min(max($0 ?? 0, Self.range.lowerBound), Self.range.upperBound) }
        )
    }

    private func step(by amount: Int) {
        value = min(max(value + amount, Self.range.lowerBound), Self.range.upperBound)
    }
}

/// The result in one line above the keyboard while typing.
private struct LiveResultBar: View {
    let result: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "equal")
                .font(.headline)
            VStack(alignment: .leading, spacing: 0) {
                Text(result, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.headline)
                    .contentTransition(.numericText())
                Text(result, format: .dateTime.hour().minute())
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy, value: result)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Result"))
        .accessibilityValue(Text(result, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute()))
    }
}
