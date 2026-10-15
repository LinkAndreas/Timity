import SwiftUI

/// What the Astronomy tab shows.
enum SkySection: String, CaseIterable, Identifiable {
    case sun, moon

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .sun: "common.sun"
        case .moon: "common.moon"
        }
    }
}

/// Switches the Astronomy tab between the Sun and the Moon.
struct SkySectionPicker: View {
    @Binding var selection: SkySection

    var body: some View {
        Picker("astronomy.show", selection: $selection.animation()) {
            ForEach(SkySection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
    }
}

/// The day shown, with a way back to today.
struct SkyDayPicker: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            DatePicker("common.date", selection: $date, displayedComponents: .date)
                .labelsHidden()
            Spacer()
            if !Calendar.autoupdatingCurrent.isDateInToday(date) {
                Button("common.today") {
                    withAnimation { date = .now }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: Calendar.autoupdatingCurrent.isDateInToday(date))
    }
}

/// The Moon: its phase on the chosen day, the month's phases day by day, when it
/// rises and sets, the next phases and the year's full moons. Everything but rise
/// and set works without a place.
struct MoonContent: View {
    let place: Place?
    @Binding var date: Date
    let now: Date

    var body: some View {
        let timeZone = place?.timeZone ?? .autoupdatingCurrent
        let time = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)

        VStack(spacing: 16) {
            MoonPhaseHero(date: date, now: now, timeZone: timeZone)
            MoonCalendarCard(date: $date, now: now, timeZone: timeZone)
            MoonTimesCard(place: place, date: date, now: now, time: time)
            FullMoonsCard(date: date, now: now, timeZone: timeZone)
            if place == nil {
                Label("astronomy.chooseAPlaceToSee", systemImage: "mappin.and.ellipse")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The Moon on the chosen day, large: its phase, light and age, and how long
/// until the next full and new moon.
private struct MoonPhaseHero: View {
    let date: Date
    let now: Date
    let timeZone: TimeZone

    var body: some View {
        let moment = MoonMoment.of(date, now: now, timeZone: timeZone)
        let moon = Astronomy.moon(at: moment)
        let nextFull = Astronomy.next(.fullMoon, after: moment)
        let nextNew = Astronomy.next(.newMoon, after: moment)

        VStack(spacing: 14) {
            Image(systemName: moon.phase.symbolName)
                .font(.system(size: 96))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.yellow)
                .shadow(color: .yellow.opacity(0.35), radius: 24)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(MoonTimesCard.name(moon.phase))
                    .font(.title2.weight(.bold))
                Text("astronomy.litDaysOld \(moon.illumination.formatted(.percent.precision(.fractionLength(0)))) \(Int(moon.age.rounded()))")
                    .font(.subheadline)
                    .opacity(0.85)
            }
            HStack(spacing: 10) {
                chip(.fullMoon, at: nextFull, now: moment)
                chip(.newMoon, at: nextNew, now: moment)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 0.07, green: 0.09, blue: 0.22), Color(red: 0.18, green: 0.16, blue: 0.38)], startPoint: .top, endPoint: .bottom),
            in: .rect(cornerRadius: 32, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    /// "Full Moon · in 5 days".
    private func chip(_ phase: Astronomy.PrincipalPhase, at when: Date, now: Date) -> some View {
        let countdown = Countdown(startDate: when, isAllDay: false, recurrence: .never, now: now, calendar: .autoupdatingCurrent)
        return VStack(spacing: 2) {
            Label {
                Text(MoonTimesCard.name(phase))
            } icon: {
                Image(systemName: MoonTimesCard.symbol(phase))
            }
            .font(.caption.weight(.semibold))
            Text(CountdownText.relativeDays(countdown))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

/// The chosen day's month with each day's Moon; days with a principal phase are
/// ringed, and tapping a day shows it.
private struct MoonCalendarCard: View {
    @Binding var date: Date
    let now: Date
    let timeZone: TimeZone

    var body: some View {
        let calendar = MoonMoment.calendar(in: timeZone)
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 86_400 * 30)
        let days = Self.days(in: month, calendar: calendar)
        let phases = Astronomy.phases(from: month.start, to: month.end)
        let leading = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        let symbols = Self.weekdaySymbols(calendar)

        Card(title: "astronomy.moonCalendar") {
            HStack {
                Button("astronomy.previousMonth", systemImage: "chevron.backward") { move(by: -1, calendar: calendar) }
                    .labelStyle(.iconOnly)
                Spacer()
                Text(month.start, format: Date.FormatStyle(timeZone: timeZone).month(.wide).year())
                    .font(.headline)
                Spacer()
                Button("astronomy.nextMonth", systemImage: "chevron.forward") { move(by: 1, calendar: calendar) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(days, id: \.self) { day in
                    let phase = phases.first { calendar.isDate($0.date, inSameDayAs: day) }?.phase
                    DayCell(
                        day: calendar.component(.day, from: day),
                        moon: Astronomy.moon(at: day.addingTimeInterval(12 * 3600)).phase,
                        principal: phase,
                        isSelected: calendar.isDate(day, inSameDayAs: date),
                        isToday: calendar.isDate(day, inSameDayAs: now)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { date = day.addingTimeInterval(12 * 3600) } }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(day, format: Date.FormatStyle(timeZone: timeZone).day().month(.wide)))
                    .accessibilityValue(phase.map { Text(MoonTimesCard.name($0)) } ?? Text(MoonTimesCard.name(Astronomy.moon(at: day.addingTimeInterval(12 * 3600)).phase)))
                    .accessibilityAddTraits(.isButton)
                }
            }

            HStack(spacing: 14) {
                ForEach(Astronomy.PrincipalPhase.allCases, id: \.self) { phase in
                    Label {
                        Text(MoonTimesCard.name(phase))
                    } icon: {
                        Image(systemName: MoonTimesCard.symbol(phase))
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity)
            Text("astronomy.ringedDaysHaveANew")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func move(by months: Int, calendar: Calendar) {
        withAnimation { date = calendar.date(byAdding: .month, value: months, to: date) ?? date }
    }

    private static func days(in month: DateInterval, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var day = month.start
        while day < month.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? month.end
        }
        return days
    }

    /// "M", "T", … starting on the calendar's first weekday.
    private static func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

private struct DayCell: View {
    let day: Int
    let moon: Astronomy.MoonPhase
    let principal: Astronomy.PrincipalPhase?
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(day, format: .number)
                .font(.caption.weight(isToday ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            Image(systemName: principal.map(MoonTimesCard.symbol) ?? moon.symbolName)
                .font(.system(size: 17))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.yellow)
                .padding(3)
                .overlay {
                    if principal != nil {
                        Circle().strokeBorder(.yellow, lineWidth: 1.5)
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.tint.opacity(0.18))
            }
        }
    }
}

/// The year's full moons, the second in a month marked as a blue moon.
private struct FullMoonsCard: View {
    let date: Date
    let now: Date
    let timeZone: TimeZone

    var body: some View {
        let calendar = MoonMoment.calendar(in: timeZone)
        let fullMoons = Astronomy.fullMoons(inYearOf: date, calendar: calendar)
        let style = Date.FormatStyle.shortDate(withTime: true, in: timeZone)
        let year = calendar.component(.year, from: date)

        Card(title: LocalizedStringKey("astronomy.fullMoonsIn \(String(year))")) {
            VStack(spacing: 10) {
                ForEach(fullMoons, id: \.self) { full in
                    LabeledContent {
                        Text(verbatim: full.date.formatted(style))
                            .monospacedDigit()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "moonphase.full.moon")
                                .foregroundStyle(full.isBlueMoon ? .blue : .yellow)
                                .accessibilityHidden(true)
                            if full.isBlueMoon {
                                Text("astronomy.blueMoon")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.15), in: .capsule)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .opacity(full.date < now ? 0.45 : 1)
                }
            }
            if fullMoons.contains(where: \.isBlueMoon) {
                Text("astronomy.aBlueMoonIsThe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The moment a day's Moon is shown for.
nonisolated enum MoonMoment {
    /// Today's Moon as it is now; another day's at noon.
    static func of(_ date: Date, now: Date, timeZone: TimeZone) -> Date {
        let calendar = calendar(in: timeZone)
        return calendar.isDate(now, inSameDayAs: date) ? now : calendar.startOfDay(for: date).addingTimeInterval(12 * 3600)
    }

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        return calendar
    }
}
