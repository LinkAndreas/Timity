import SwiftUI

/// A date moved forwards or backwards by days, weeks, months and years — and,
/// with times, by hours and minutes too.
///
/// Built for quick answers: common amounts one tap away, empty fields instead
/// of zeros, Next and Previous above the keyboard, and the result shown live
/// above the keyboard while typing.
struct AddSubtractView: View {
    /// The fields, in the order Next moves through them.
    enum Field: Hashable, CaseIterable {
        case days, weeks, months, years, hours, minutes

        var unit: TimeUnit {
            switch self {
            case .days: .day
            case .weeks: .week
            case .months: .month
            case .years: .year
            case .hours: .hour
            case .minutes: .minute
            }
        }

        /// The fields shown, in the order Next moves through them.
        static func shown(includingTime: Bool) -> [Field] {
            includingTime ? allCases : [.days, .weeks, .months, .years]
        }

        /// Largest first, for the question in words.
        static let largestFirst: [Field] = [.years, .months, .weeks, .days, .hours, .minutes]
    }

    /// Keeps the result as an event and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    @State private var start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var subtracts = false
    @State private var includesTime = false
    @State private var offset = TimeBreakdown(days: 90)
    @State private var savedCount = 0
    @FocusState private var focus: Field?

    /// Amounts people often need: notice periods, returns, warranties.
    private static let presets: [TimeBreakdown] = [
        TimeBreakdown(weeks: 1), TimeBreakdown(days: 30), TimeBreakdown(days: 90),
        TimeBreakdown(months: 6), TimeBreakdown(years: 1),
    ]

    /// With times, short spans come first: a parking ticket, a shift, a flight.
    private static let timePresets: [TimeBreakdown] = [
        TimeBreakdown(minutes: 30), TimeBreakdown(hours: 1), TimeBreakdown(hours: 8), TimeBreakdown(hours: 48),
        TimeBreakdown(weeks: 1), TimeBreakdown(days: 30),
    ]

    private var fields: [Field] { Field.shown(includingTime: includesTime) }

    var body: some View {
        SideBySideForm {
            Section {
                DateRow(title: "Start Date", date: $start, includesTime: includesTime)
                Toggle("Include Time", isOn: timeToggle.animation())
                Picker("Direction", selection: $subtracts.animation()) {
                    Text("Later").tag(false)
                    Text("Earlier").tag(true)
                }
                .pickerStyle(.segmented)
            }

            // Common amounts, one tap away, above the fields they fill in.
            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(includesTime ? Self.timePresets : Self.presets, id: \.self) { preset in
                            Button(presetName(preset)) {
                                withAnimation { offset = preset }
                                focus = nil
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .tint(offset == preset ? .accentColor : .secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("How Far")
            }
        } trailing: {
            // The answer right under the question; the exact fields below fine-tune it.
            if let result {
                Section {
                    ResultHero(color: .purple) {
                        // The question in a sentence, so the answer reads on its own.
                        Text(question)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                            .opacity(0.9)
                        Text(result, format: .dateTime.weekday(.wide))
                            .font(.title3.weight(.semibold))
                            .opacity(0.9)
                        Text(result, format: .dateTime.day().month(.wide).year())
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        if includesTime {
                            Text(result, format: .dateTime.hour().minute())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        Text("Week \(DateMath.weekOfYear(result))")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .animation(.snappy, value: result)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(fields, id: \.self) { field in
                    AmountField(field: field, value: binding(for: field), focus: $focus, onSubmit: moveToNextField)
                }
            } footer: {
                if includesTime {
                    Text("Hours and minutes are time that really passes, also when the clocks change. A month after 31 January is the last day of February.")
                } else {
                    Text("A month after 31 January is the last day of February.")
                }
            }

            if let result {
                Section {
                    Button {
                        save(result)
                    } label: {
                        // The frame inside the label, so the glass spans the row.
                        Label(includesTime ? LocalizedStringKey("Count Down to This Time") : LocalizedStringKey("Count Down to This Date"), systemImage: "calendar.badge.plus")
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
        .navigationTitle("Find a Date")
        // While typing, the result stays in sight just above the keyboard.
        .safeAreaInset(edge: .bottom) {
            if focus != nil, let result {
                LiveResultBar(result: result, includesTime: includesTime)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: focus)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation { offset = TimeBreakdown() }
                }
                .disabled(offset.isZero)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Button("Previous Field", systemImage: "chevron.up") { moveFocus(by: -1) }
                    .disabled(focus == fields.first)
                Button("Next Field", systemImage: "chevron.down") { moveFocus(by: 1) }
                    .disabled(focus == fields.last)
                Spacer()
                Button("Done") { focus = nil }
                    .fontWeight(.semibold)
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Fields and focus

    private func binding(for field: Field) -> Binding<Int> {
        switch field {
        case .days: $offset.days
        case .weeks: $offset.weeks
        case .months: $offset.months
        case .years: $offset.years
        case .hours: $offset.hours
        case .minutes: $offset.minutes
        }
    }

    /// "30 days", "6 months".
    private func presetName(_ preset: TimeBreakdown) -> String {
        let field = Field.largestFirst.first { value(of: $0, in: preset) != 0 } ?? .days
        let amount = value(of: field, in: preset)
        return "\(amount.formatted()) \(CountdownText.unit(field.unit, value: amount))"
    }

    private func value(of field: Field, in breakdown: TimeBreakdown) -> Int {
        switch field {
        case .days: breakdown.days
        case .weeks: breakdown.weeks
        case .months: breakdown.months
        case .years: breakdown.years
        case .hours: breakdown.hours
        case .minutes: breakdown.minutes
        }
    }

    private func moveFocus(by step: Int) {
        guard let focus, let index = fields.firstIndex(of: focus) else { return }
        let next = index + step
        guard fields.indices.contains(next) else { return }
        self.focus = fields[next]
    }

    /// Return moves on; on the last field it closes the keyboard.
    private func moveToNextField() {
        if focus == fields.last { focus = nil } else { moveFocus(by: 1) }
    }

    // MARK: Result

    /// "90 days after Tuesday, 13 October 2026", with the time when times are on.
    private var question: String {
        let parts = Field.largestFirst.compactMap { field -> String? in
            let amount = value(of: field, in: offset)
            return amount == 0 ? nil : "\(amount.formatted()) \(CountdownText.unit(field.unit, value: amount))"
        }
        let amount = parts.isEmpty ? "0 \(CountdownText.unit(.day, value: 0))" : parts.formatted(.list(type: .and))
        let day = includesTime
            ? start.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
            : start.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        return subtracts ? String(localized: "\(amount) before \(day)") : String(localized: "\(amount) after \(day)")
    }

    private var result: Date? {
        DateMath.date(start, movedBy: offset, backwards: subtracts)
    }

    /// Turning times on starts at the current time on the chosen day; turning them off
    /// goes back to whole days and drops the hours and minutes.
    private var timeToggle: Binding<Bool> {
        Binding(
            get: { includesTime },
            set: { includesTime in
                if includesTime {
                    start = DateMath.date(start, atTimeOf: .now)
                } else {
                    start = Calendar.autoupdatingCurrent.startOfDay(for: start)
                    offset.hours = 0
                    offset.minutes = 0
                    if let focus, !Field.shown(includingTime: false).contains(focus) { self.focus = nil }
                }
                self.includesTime = includesTime
            }
        )
    }

    private func save(_ date: Date) {
        savedCount += 1
        var event = EventSnapshot(
            title: date.formatted(date: .long, time: includesTime ? .shortened : .omitted),
            isAllDay: !includesTime,
            symbolName: "calendar"
        )
        event.setStartDate(date)
        onSaveAsEvent(event)
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
            Text(CountdownText.unit(field.unit, value: value == 1 ? 1 : 2).localizedCapitalized)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Plain digits: a formatted field with a return key opens the letter
            // keyboard for a moment before the number pad.
            TextField(CountdownText.unit(field.unit, value: 2).localizedCapitalized, text: text, prompt: Text(verbatim: "0"))
            .keyboardType(.numberPad)
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
    private var text: Binding<String> {
        Binding(
            get: { value == 0 ? "" : String(value) },
            set: { typed in
                let digits = typed.filter(\.isWholeNumber).prefix(6)
                value = min(max(Int(digits) ?? 0, Self.range.lowerBound), Self.range.upperBound)
            }
        )
    }

    private func step(by amount: Int) {
        value = min(max(value + amount, Self.range.lowerBound), Self.range.upperBound)
    }
}

/// The result in one line above the keyboard while typing.
private struct LiveResultBar: View {
    let result: Date
    let includesTime: Bool

    private var format: Date.FormatStyle {
        includesTime
            ? .dateTime.weekday(.wide).day().month(.wide).year().hour().minute()
            : .dateTime.weekday(.wide).day().month(.wide).year()
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "equal")
                .font(.headline)
            Text(result, format: format)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .animation(.snappy, value: result)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Result"))
        .accessibilityValue(Text(result, format: format))
    }
}
