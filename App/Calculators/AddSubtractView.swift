import SwiftUI
import TipKit

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
                DateRow(title: "calc.addSubtract.startDate", date: $start, includesTime: includesTime, showsTip: true)
                Toggle("common.includeTime", isOn: timeToggle.animation())
                Picker("calc.addSubtract.direction", selection: $subtracts.animation()) {
                    Text("calc.addSubtract.later").tag(false)
                    Text("calc.addSubtract.earlier").tag(true)
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
                                QuickAmountsTip().invalidate(reason: .actionPerformed)
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
                .popoverTip(QuickAmountsTip(), arrowEdge: .top)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("calc.addSubtract.howFar")
            }
        } trailing: {
            Section {
                ForEach(fields, id: \.self) { field in
                    AmountField(field: field, value: binding(for: field), focus: $focus, onSubmit: moveToNextField)
                }
            } footer: {
                if includesTime {
                    Text("calc.addSubtract.hoursAndMinutesAreTime")
                } else {
                    Text("calc.addSubtract.aMonthAfter31January")
                }
            }

            // The answer last, after everything that sets it, with its button right below.
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
                            .scaledFont(size: 34, weight: .heavy, design: .rounded, relativeTo: .title)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        if includesTime {
                            Text(result, format: .dateTime.hour().minute())
                                .scaledFont(size: 28, weight: .bold, design: .rounded, relativeTo: .title3, maxScale: 2)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        Text("common.week \(DateMath.weekOfYear(result).formatted())")
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

            if let result {
                Section {
                    Button {
                        save(result)
                    } label: {
                        // The frame inside the label, so the glass spans the row.
                        Label(includesTime ? LocalizedStringKey("calc.addSubtract.countDownToThisTime") : LocalizedStringKey("calc.addSubtract.countDownToThisDate"), systemImage: "calendar.badge.plus")
                            .font(.headline)
                            // In a list, a label puts its icon at the row's edge in the tint, which
                            // vanishes on the tinted button: icon and title together, in white.
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.white)
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
        .navigationTitle("common.findADate")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("calc.addSubtract.reset", systemImage: "arrow.counterclockwise") {
                    withAnimation { offset = TimeBreakdown() }
                }
                .disabled(offset.isZero)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Button("calc.addSubtract.previousField", systemImage: "chevron.up") { moveFocus(by: -1) }
                    .disabled(focus == fields.first)
                Button("calc.addSubtract.nextField", systemImage: "chevron.down") { moveFocus(by: 1) }
                    .disabled(focus == fields.last)
                Spacer()
                // While typing, the result stays in sight in the keyboard's own bar,
                // where nothing can cover it.
                if let result {
                    LiveResult(result: result, includesTime: includesTime)
                }
                Spacer()
                Button("common.done") { focus = nil }
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
        let day = start.formatted(.fullDate(withTime: includesTime))
        return subtracts ? String(localized: "calc.addSubtract.before \(amount) \(day)") : String(localized: "calc.addSubtract.after \(amount) \(day)")
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
            .labelsHidden()
            .numberPadKeyboard()
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
            get: { value == 0 ? "" : value.formatted(.number.grouping(.never)) },
            set: { typed in
                // Digits in any script the keyboard types: 12, ١٢, १२.
                let digits = typed.compactMap(\.wholeNumberValue).prefix(6)
                let typedValue = digits.reduce(0) { $0 * 10 + $1 }
                value = min(max(typedValue, Self.range.lowerBound), Self.range.upperBound)
            }
        )
    }

    private func step(by amount: Int) {
        value = min(max(value + amount, Self.range.lowerBound), Self.range.upperBound)
    }
}

/// The result in one line in the keyboard's bar while typing.
private struct LiveResult: View {
    let result: Date
    let includesTime: Bool

    private var format: Date.FormatStyle {
        .shortDate(withTime: includesTime)
    }

    var body: some View {
        Text(result, format: format)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(.numericText())
            .animation(.snappy, value: result)
            .accessibilityLabel(Text("calc.addSubtract.result"))
            .accessibilityValue(Text(result, format: format))
    }
}
