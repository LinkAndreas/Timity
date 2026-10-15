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
        VStack(spacing: 0) {
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

            if let openPart {
                panel(openPart)
                    .transition(.opacity)
            }
        }
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
        // Borderless, so in a list each pill is its own button rather than the whole row.
        .buttonStyle(.borderless)
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
                DatePicker(title, selection: $date, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            case .time:
                DatePicker(title, selection: $date, in: range, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
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
        .padding(.top, 8)
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
        .buttonStyle(.borderless)
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: 44)
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
