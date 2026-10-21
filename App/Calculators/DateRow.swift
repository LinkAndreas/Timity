import SwiftUI
import TipKit

/// A date, or a date and time, as in Calendar's event editor: the title, and the
/// date and time as pills on one line; tapping one opens a calendar or a time wheel
/// right below, and tapping it again closes it.
///
/// The pills show Timity's own text, so every row reads alike and lines up: the
/// system's compact picker picks its own format and width, and fell back to
/// "15.11.2026" when a later date's name was longer.
struct DateRow: View {
    enum Part: Hashable {
        case date, time
    }

    let title: LocalizedStringKey
    @Binding var date: Date
    /// Off for a time of day alone, as for a bedtime.
    var includesDate = true
    let includesTime: Bool
    /// The dates that can be picked.
    var range: ClosedRange<Date> = Date.distantPast...Date.distantFuture
    /// A way back to today, or now, in the open calendar or wheel; off where that
    /// means nothing, as for a birthday.
    var showsReset = true
    /// What "Now" does instead of setting the time, as where now means following the clock.
    var resetToNow: (() -> Void)?
    /// Points out, once, that the date opens a calendar: on a calculator's first date.
    var showsTip = false

    /// Shared by every row on screen, so opening one closes the other, as in Calendar.
    @Environment(DateRowFocus.self) private var focus: DateRowFocus?
    @Environment(\.timeZone) private var timeZone
    @State private var id = UUID()
    /// Where no focus is shared, as in a preview.
    @State private var ownOpenPart: Part?

    var body: some View {
        // Two views, not one: in a list each is its own row, so opening adds a row
        // that the list slides in, as in Calendar, instead of stretching this one.
        Group {
            header
            if let openPart {
                panel(openPart)
            }
        }
    }

    private var header: some View {
        // On one line when it fits; at large text sizes the pills move below the title.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(title)
                Spacer(minLength: 12)
                pills
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                pills
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
        .onChange(of: includesTime) { _, hasTime in
            if !hasTime, openPart == .time { setOpenPart(nil) }
        }
        .onDisappear {
            if openPart != nil { setOpenPart(nil) }
        }
    }

    // MARK: Pills

    private var pills: some View {
        HStack(spacing: 8) {
            if includesDate {
                pill(Text(date, format: dateStyle), part: .date)
            }
            if includesTime {
                pill(Text(date, format: timeStyle), part: .time)
            }
        }
        .fixedSize()
    }

    private func pill(_ text: Text, part: Part) -> some View {
        let isOpen = openPart == part
        return Button {
            withAnimation(.snappy) { setOpenPart(isOpen ? nil : part) }
            DatePillTip().invalidate(reason: .actionPerformed)
        } label: {
            text
                .monospacedDigit()
                .foregroundStyle(isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.fill.tertiary, in: .capsule)
                .contentShape(.capsule)
        }
        // Plain, so in a list each pill is its own button rather than the whole row,
        // and only the open one is tinted.
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(text)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .popoverTip(showsTip && part == .date ? DatePillTip() : nil, arrowEdge: .top)
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: timeZone)
    }

    private var timeStyle: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
    }

    // MARK: Calendar and wheel

    private func panel(_ part: Part) -> some View {
        VStack(spacing: 0) {
            switch part {
            case .date:
                #if os(macOS)
                // The Mac's own calendar is a small control of a fixed size; this one fills the row.
                MonthCalendar(date: $date, range: range, calendar: calendar)
                #else
                DatePicker(title, selection: $date, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                #endif
            case .time:
                #if os(macOS)
                // The Mac's own time field is small; this one is as large as the calendar's days.
                TimeOfDayPicker(date: $date, range: range, calendar: calendar)
                #else
                DatePicker(title, selection: $date, in: range, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                #endif
            }
            if showsReset {
                HStack {
                    Spacer()
                    resetButton(for: part)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// "Today" under the calendar, keeping the time of day; "Now" under the wheel.
    /// Dimmed while it would change nothing.
    private func resetButton(for part: Part) -> some View {
        let isToday = part == .date
        return Button(isToday ? LocalizedStringKey("common.today") : LocalizedStringKey("common.now")) {
            withAnimation(.snappy) {
                if part == .time, let resetToNow {
                    resetToNow()
                } else {
                    date = min(max(resetDate(for: part), range.lowerBound), range.upperBound)
                }
            }
        }
        // A tinted capsule, so it reads as a button at a glance; grey while it would
        // change nothing.
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .font(.subheadline.weight(.semibold))
        .padding(.vertical, 6)
        .disabled(isCurrent(part))
        .accessibilityLabel(isToday ? Text("common.setToToday") : Text("common.setToNow"))
    }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        return calendar
    }

    private func resetDate(for part: Part) -> Date {
        let today = calendar.startOfDay(for: .now)
        switch part {
        case .time:
            return .now
        case .date where includesTime:
            let time = calendar.dateComponents([.hour, .minute], from: date)
            return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: today) ?? today
        case .date:
            return today
        }
    }

    private func isCurrent(_ part: Part) -> Bool {
        switch part {
        case .date: calendar.isDate(date, inSameDayAs: .now)
        case .time: abs(date.timeIntervalSinceNow) < 60
        }
    }

    // MARK: Which part is open

    private var openPart: Part? {
        guard let focus else { return ownOpenPart }
        return focus.open?.row == id ? focus.open?.part : nil
    }

    private func setOpenPart(_ part: Part?) {
        if let focus {
            if let part {
                focus.open = DateRowFocus.Open(row: id, part: part)
            } else if focus.open?.row == id {
                focus.open = nil
            }
        } else {
            ownOpenPart = part
        }
    }
}

/// Which date row has its calendar or wheel open, so only one is at a time.
@Observable
final class DateRowFocus {
    struct Open: Equatable {
        let row: UUID
        let part: DateRow.Part
    }

    var open: Open?
}


#if os(macOS)
/// A month to pick a day from, as wide as the row it opens in, as the iPhone's calendar is:
/// the month with arrows to the ones before and after, the days of the week, and six weeks
/// of days, so it keeps its height from month to month; the chosen day is filled, today is
/// in the tint and the neighbouring months' days are dimmed. Picking a day keeps the time of
/// day. Clicked into, the arrow keys move the chosen day and Page Up and Down the month.
private struct MonthCalendar: View {
    @Binding var date: Date
    let range: ClosedRange<Date>
    let calendar: Calendar

    /// The first day of the month shown, which the arrows change without picking a day.
    @State private var month: Date
    /// Which way the month last moved, so the next one slides in from that side.
    @State private var direction = 1
    /// Focused once a day is clicked, so the arrow keys go on from it.
    @FocusState private var isFocused: Bool

    init(date: Binding<Date>, range: ClosedRange<Date>, calendar: Calendar) {
        _date = date
        self.range = range
        self.calendar = calendar
        _month = State(initialValue: calendar.dateInterval(of: .month, for: date.wrappedValue)?.start ?? date.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // The Mac's own controls for going far back or ahead at once, as for a birth year:
                // the month in a pop-up menu, the year typed or stepped.
                Picker("common.month", selection: monthNumber) {
                    ForEach(1...12, id: \.self) { number in
                        Text(calendar.standaloneMonthSymbols[number - 1]).tag(number)
                    }
                }
                .labelsHidden()
                .fixedSize()
                TextField("common.year", value: year, format: .number.grouping(.never))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                Stepper("common.year", value: year)
                    .labelsHidden()
                Spacer()
                monthButton("astronomy.previousMonth", systemImage: "chevron.backward", by: -1)
                monthButton("astronomy.nextMonth", systemImage: "chevron.forward", by: 1)
            }
            .font(.headline)

            HStack(spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(0..<6, id: \.self) { week in
                    GridRow {
                        ForEach(days[(week * 7)..<(week * 7 + 7)], id: \.self) { day in
                            dayButton(day)
                        }
                    }
                }
            }
            .id(month)
            .transition(.asymmetric(
                insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
            ))
            .clipped()
        }
        // Keys move the chosen day once the calendar is clicked into, as in Calendar's month.
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { move(days: -1) }
        .onKeyPress(.rightArrow) { move(days: 1) }
        .onKeyPress(.upArrow) { move(days: -7) }
        .onKeyPress(.downArrow) { move(days: 7) }
        .onKeyPress(.pageUp) { move(months: -1) }
        .onKeyPress(.pageDown) { move(months: 1) }
        // Picked elsewhere, as with Today or the keys, a day in another month shows that month.
        .onChange(of: date) {
            if let start = calendar.dateInterval(of: .month, for: date)?.start, start != month {
                showMonth(start)
            }
        }
    }

    /// The month shown, as its number in the year, for the month menu.
    private var monthNumber: Binding<Int> {
        Binding(
            get: { calendar.component(.month, from: month) },
            set: { show(year: calendar.component(.year, from: month), month: $0) }
        )
    }

    /// The year shown, for the year field and its stepper.
    private var year: Binding<Int> {
        Binding(
            get: { calendar.component(.year, from: month) },
            set: { show(year: $0, month: calendar.component(.month, from: month)) }
        )
    }

    private func show(year: Int, month number: Int) {
        guard (1...9999).contains(year),
              let start = calendar.date(from: DateComponents(year: year, month: number, day: 1)),
              let interval = calendar.dateInterval(of: .month, for: start),
              interval.end > range.lowerBound, interval.start <= range.upperBound else { return }
        showMonth(start)
    }

    /// An arrow to the month before or after, easy to hit rather than as small as its symbol.
    private func monthButton(_ title: LocalizedStringKey, systemImage: String, by months: Int) -> some View {
        Button {
            show(by: months)
        } label: {
            Image(systemName: systemImage)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .disabled(!canShow(by: months))
        .accessibilityLabel(Text(title))
    }

    private func dayButton(_ day: Date) -> some View {
        let isChosen = calendar.isDate(day, inSameDayAs: date)
        let isToday = calendar.isDateInToday(day)
        let isInMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isAllowed = range.contains(day) || calendar.isDate(day, inSameDayAs: range.lowerBound)
        let style: AnyShapeStyle = isChosen ? AnyShapeStyle(.white)
            : isToday ? AnyShapeStyle(.tint)
            : isInMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
        return Button {
            pick(day)
            isFocused = true
        } label: {
            Text(day.formatted(Date.FormatStyle(timeZone: calendar.timeZone).day()))
                .font(.body.weight(isChosen || isToday ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(style)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background {
                    if isChosen {
                        Circle().fill(.tint).frame(width: 32, height: 32)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isAllowed)
        .opacity(isAllowed ? 1 : 0.3)
        .accessibilityLabel(Text(day.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: calendar.timeZone))))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// The day picked, at the time of day already set.
    private func pick(_ day: Date) {
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        let picked = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
        withAnimation(.snappy) {
            date = min(max(picked, range.lowerBound), range.upperBound)
        }
    }

    private func move(days: Int) -> KeyPress.Result {
        guard let day = calendar.date(byAdding: .day, value: days, to: date) else { return .ignored }
        pick(day)
        return .handled
    }

    private func move(months: Int) -> KeyPress.Result {
        guard let day = calendar.date(byAdding: .month, value: months, to: date) else { return .ignored }
        pick(day)
        return .handled
    }

    private func show(by months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: month) {
            showMonth(next)
        }
    }

    private func showMonth(_ next: Date) {
        direction = next > month ? 1 : -1
        withAnimation(.snappy) { month = next }
    }

    /// Whether the month before or after holds a day that can be picked.
    private func canShow(by months: Int) -> Bool {
        guard let next = calendar.date(byAdding: .month, value: months, to: month),
              let interval = calendar.dateInterval(of: .month, for: next) else { return false }
        return interval.end > range.lowerBound && interval.start <= range.upperBound
    }

    /// Mon, Tue, … from the week's first day where the user lives.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Six weeks of days from the week the month starts in, the neighbouring months' included.
    private var days: [Date] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        guard let first = calendar.date(byAdding: .day, value: -leading, to: start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }
}

/// A time of day in large hours and minutes, as the Mac's own time field behaves: clicked, a number
/// is selected, so typing replaces it, and a complete hour moves on to the minutes; the left and
/// right keys move between them, up and down step (with Shift, minutes by five), and A and P set
/// the half of the day where the clock has one. The arrows above and below step too, and repeat
/// while held.
private struct TimeOfDayPicker: View {
    @Binding var date: Date
    let range: ClosedRange<Date>
    let calendar: Calendar

    enum Unit: Hashable { case hour, minute }

    @FocusState private var focus: Unit?

    private var uses12HourClock: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: calendar.locale ?? .current)?.contains("a") == true
    }

    private var hour: Int { calendar.component(.hour, from: date) }
    private var minute: Int { calendar.component(.minute, from: date) }

    var body: some View {
        HStack(spacing: 10) {
            TimeUnitField(
                title: "common.hours",
                unit: .hour,
                focus: $focus,
                value: Binding(
                    get: { uses12HourClock ? (hour + 11) % 12 + 1 : hour },
                    set: { shown in
                        guard uses12HourClock else { return set(hour: shown) }
                        set(hour: shown % 12 + (hour >= 12 ? 12 : 0))
                    }
                ),
                range: uses12HourClock ? 1...12 : 0...23,
                isPadded: !uses12HourClock,
                largeStep: 1,
                onMeridiem: meridiemSetter
            )
            Text(verbatim: ":")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            TimeUnitField(
                title: "common.minutes",
                unit: .minute,
                focus: $focus,
                value: Binding(get: { minute }, set: { set(minute: $0) }),
                range: 0...59,
                largeStep: 5,
                onMeridiem: meridiemSetter
            )
            if uses12HourClock {
                Picker("common.time", selection: Binding(get: { hour >= 12 }, set: { isPM in setMeridiem(isPM: isPM) })) {
                    Text(calendar.amSymbol).tag(false)
                    Text(calendar.pmSymbol).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .padding(.leading, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    /// Sets AM or PM from a typed A or P; nil on a 24-hour clock.
    private var meridiemSetter: ((Bool) -> Void)? {
        guard uses12HourClock else { return nil }
        return { isPM in setMeridiem(isPM: isPM) }
    }

    private func setMeridiem(isPM: Bool) {
        set(hour: hour % 12 + (isPM ? 12 : 0))
    }

    private func set(hour: Int? = nil, minute: Int? = nil) {
        guard let changed = calendar.date(bySettingHour: hour ?? self.hour, minute: minute ?? self.minute, second: 0, of: date) else { return }
        date = min(max(changed, range.lowerBound), range.upperBound)
    }
}

/// Hours or minutes: a large number to type in, between arrows that step it.
private struct TimeUnitField: View {
    let title: LocalizedStringKey
    let unit: TimeOfDayPicker.Unit
    var focus: FocusState<TimeOfDayPicker.Unit?>.Binding
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// Two digits, as minutes and the hours of a 24-hour clock are written; "9" rather than "09" otherwise.
    var isPadded = true
    /// How far up and down go with Shift held.
    var largeStep = 1
    /// Sets AM (false) or PM (true) when A or P is typed; nil on a 24-hour clock.
    var onMeridiem: ((Bool) -> Void)?

    @State private var text = ""
    @State private var selection: TextSelection?
    /// Whether the text is being typed, rather than shown after a step or a change elsewhere.
    @State private var isTyping = false

    private var isFocused: Bool { focus.wrappedValue == unit }

    var body: some View {
        VStack(spacing: 2) {
            arrow("chevron.up", by: 1)
            TextField(title, text: $text, selection: $selection)
                // In a form the Mac would put the title beside the number and squeeze it.
                .labelsHidden()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(width: 64, height: 44)
                .background(.quaternary, in: .rect(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.tint, lineWidth: 2)
                        .opacity(isFocused ? 1 : 0)
                }
                .focused(focus, equals: unit)
                // Before the field moves its cursor with them, as up and down step the Mac's own time field.
                .onKeyPress(keys: [.upArrow, .downArrow], phases: [.down, .repeat]) { press in
                    commit()
                    let amount = press.modifiers.contains(.shift) ? largeStep : 1
                    step(by: press.key == .upArrow ? amount : -amount)
                    return .handled
                }
                // Left and right move between hours and minutes, as in the Mac's own time field.
                .onKeyPress(keys: [.leftArrow, .rightArrow], phases: .down) { press in
                    commit()
                    focus.wrappedValue = press.key == .leftArrow ? .hour : .minute
                    return .handled
                }
                .onKeyPress(phases: .down) { press in
                    let key = press.characters.lowercased()
                    if key.allSatisfy(\.isNumber), !key.isEmpty {
                        isTyping = true
                        return .ignored
                    }
                    // The separator moves on to the minutes, as when typing a time in full.
                    if unit == .hour, [":", ".", " "].contains(key) {
                        commit()
                        focus.wrappedValue = .minute
                        return .handled
                    }
                    if let onMeridiem, let first = key.first, ["a", "p"].contains(first) {
                        commit()
                        onMeridiem(first == "p")
                        return .handled
                    }
                    return .ignored
                }
                .onChange(of: text) { typed(text) }
                .onSubmit(commit)
                .onChange(of: isFocused) {
                    if isFocused { selectAll() } else { commit() }
                }
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(verbatim: String(value)))
                .accessibilityAdjustableAction { direction in
                    step(by: direction == .increment ? 1 : -1)
                }
            arrow("chevron.down", by: -1)
        }
        .onAppear { show() }
        .onChange(of: value) { show() }
    }

    private func arrow(_ systemImage: String, by step: Int) -> some View {
        Button {
            self.step(by: step)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 64, height: 22)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .buttonRepeatBehavior(.enabled)
        .accessibilityHidden(true)
    }

    /// Once the typed digits can't become a larger number in range, takes them and moves on to the minutes.
    private func typed(_ text: String) {
        guard isTyping, isFocused else { return }
        let digits = text.filter(\.isNumber)
        if digits != text { self.text = digits }
        guard let number = Int(digits) else { return }
        let isComplete = digits.count >= 2 || number * 10 > range.upperBound
        guard isComplete else { return }
        commit()
        if unit == .hour { focus.wrappedValue = .minute } else { selectAll() }
    }

    /// One up or down, from the last back round to the first.
    private func step(by amount: Int) {
        let count = range.count
        value = range.lowerBound + ((value - range.lowerBound + amount) % count + count) % count
        if isFocused { selectAll() }
    }

    /// The typed number, if it's one in range; otherwise back to the one before.
    private func commit() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)), range.contains(typed) {
            value = typed
        }
        show()
    }

    private func show() {
        isTyping = false
        text = isPadded ? String(format: "%02d", value) : String(value)
        if isFocused { selectAll() }
    }

    /// The whole number, so typing replaces it.
    private func selectAll() {
        selection = TextSelection(range: text.startIndex..<text.endIndex)
    }
}
#endif
