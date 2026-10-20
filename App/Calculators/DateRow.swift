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
                DatePicker(title, selection: $date, in: range, displayedComponents: .hourAndMinute)
                    #if os(iOS)
                    .datePickerStyle(.wheel)
                    #else
                    // The Mac's time field, typed or stepped with the arrow keys.
                    .datePickerStyle(.stepperField)
                    #endif
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
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
    @State private var hovered: Date?
    /// Focused once a day is clicked, so the arrow keys go on from it.
    @FocusState private var isFocused: Bool
    /// The month and year picker over the title, to go far back or ahead at once, as for a birth year.
    @State private var isPickingMonth = false

    init(date: Binding<Date>, range: ClosedRange<Date>, calendar: Calendar) {
        _date = date
        self.range = range
        self.calendar = calendar
        _month = State(initialValue: calendar.dateInterval(of: .month, for: date.wrappedValue)?.start ?? date.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    isPickingMonth.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(month.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.wide).year()))
                            .contentTransition(.numericText(countsDown: direction < 0))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tint)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isPickingMonth, arrowEdge: .bottom) {
                    MonthYearPicker(month: Binding(get: { month }, set: { showMonth($0) }), range: range, calendar: calendar)
                }
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
        let isHovered = hovered.map { calendar.isDate($0, inSameDayAs: day) } == true
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
                    Circle()
                        .fill(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .frame(width: 32, height: 32)
                        .opacity(isChosen || (isHovered && isAllowed) ? 1 : 0)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isAllowed)
        .opacity(isAllowed ? 1 : 0.3)
        .onHover { inside in
            if inside { hovered = day } else if isHovered { hovered = nil }
        }
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

/// A year to type or step through, and its twelve months, for the calendar to show.
private struct MonthYearPicker: View {
    /// The first day of the month shown.
    @Binding var month: Date
    let range: ClosedRange<Date>
    let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var year: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                yearButton("common.previousYear", systemImage: "chevron.backward", by: -1)
                TextField("common.year", value: $year, format: .number.grouping(.never))
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(width: 80)
                    .onSubmit { show(monthNumber: calendar.component(.month, from: month)) }
                yearButton("common.nextYear", systemImage: "chevron.forward", by: 1)
            }

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(1...4, id: \.self) { column in
                            monthButton(row * 4 + column)
                        }
                    }
                }
            }
        }
        .padding(14)
        .onAppear { year = calendar.component(.year, from: month) }
    }

    /// An arrow to the year before or after, easy to hit rather than as small as its symbol.
    private func yearButton(_ title: LocalizedStringKey, systemImage: String, by years: Int) -> some View {
        Button {
            year += years
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(title))
    }

    private func monthButton(_ number: Int) -> some View {
        let isShown = calendar.component(.month, from: month) == number && calendar.component(.year, from: month) == year
        let isAllowed = start(of: number).map { canShow($0) } ?? false
        return Button {
            show(monthNumber: number)
            dismiss()
        } label: {
            Text(calendar.shortStandaloneMonthSymbols[number - 1])
                .font(.body.weight(isShown ? .semibold : .regular))
                .foregroundStyle(isShown ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 56, height: 30)
                .background(isShown ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(!isAllowed)
        .opacity(isAllowed ? 1 : 0.4)
    }

    private func start(of monthNumber: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: monthNumber, day: 1))
    }

    private func canShow(_ start: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: start) else { return false }
        return interval.end > range.lowerBound && interval.start <= range.upperBound
    }

    private func show(monthNumber: Int) {
        if let start = start(of: monthNumber), canShow(start) {
            month = start
        }
    }
}
#endif
