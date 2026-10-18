import SwiftUI

/// A date in one calendar shown in the world's others — Hebrew, Islamic, Chinese,
/// Persian and more — and, for calendars events can follow, when it next comes round.
struct CalendarConverterView: View {
    /// Keeps the date as a yearly event in its calendar and shows it.
    let onSaveAsEvent: (EventSnapshot) -> Void

    /// The calendars offered, the user's own first.
    static let identifiers: [Calendar.Identifier] = [
        .gregorian, .hebrew, .islamicUmmAlQura, .chinese, .persian, .indian,
        .buddhist, .japanese, .coptic, .ethiopicAmeteMihret, .republicOfChina,
    ]

    @State private var source = Calendar.Identifier.gregorian
    @State private var date = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var savedCount = 0

    var body: some View {
        SideBySideForm {
            Section {
                Picker("common.calendar", selection: $source) {
                    ForEach(Self.identifiers, id: \.self) { identifier in
                        Text(verbatim: Self.name(identifier)).tag(identifier)
                    }
                }
                // Months and years as the chosen calendar has them.
                DateRow(title: "common.date", date: $date, includesTime: false)
                    .environment(\.calendar, Self.calendar(source))
            } footer: {
                Text("calc.calendarConverter.pickTheDateAsIts")
            }
        } trailing: {
            Section {
                ResultHero(color: .mint) {
                    Text(date, format: Date.FormatStyle(calendar: Self.calendar(.gregorian)).weekday(.wide))
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(verbatim: Self.formatted(date, in: source))
                        .scaledFont(size: 30, weight: .heavy, design: .rounded, relativeTo: .title)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(verbatim: Self.name(source))
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                }
                .animation(.snappy, value: date)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("calc.calendarConverter.inOtherCalendars") {
                ForEach(Self.identifiers.filter { $0 != source }, id: \.self) { identifier in
                    ConvertedDateRow(date: Self.formatted(date, in: identifier), calendar: Self.name(identifier))
                }
            }

            if let eventCalendar = EventCalendar.allCases.first(where: { $0.identifier == source }) {
                nextTime(eventCalendar)
            }
        }
        .navigationTitle("common.calendarConverter")
        .sensoryFeedback(.success, trigger: savedCount)
    }

    /// When the date comes round again in its calendar, and a way to count down to it every year.
    private func nextTime(_ eventCalendar: EventCalendar) -> some View {
        let rule = RecurrenceRule(frequency: .yearly, calendarIdentifier: eventCalendar.identifier)
        let next = rule.occurrence(of: date, onOrAfter: Calendar.autoupdatingCurrent.startOfDay(for: .now), calendar: .autoupdatingCurrent).date
        let countdown = Countdown(startDate: next, isAllDay: true, recurrence: .never, now: .now, calendar: .autoupdatingCurrent)

        return Section {
            LabeledContent("calc.calendarConverter.nextTime") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(next, format: .dateTime.weekday(.abbreviated).day().month(.wide).year())
                    Text(CountdownText.relativeDays(countdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                save(eventCalendar)
            } label: {
                Label("calc.calendarConverter.countDownEveryYear", systemImage: "calendar.badge.plus")
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
        } footer: {
            Text("calc.calendarConverter.holidaysAndBirthdaysKeptBy")
        }
    }

    private func save(_ eventCalendar: EventCalendar) {
        savedCount += 1
        var event = EventSnapshot(title: Self.formatted(date, in: source), isAllDay: true, recurrence: .yearly, symbolName: "calendar")
        event.eventCalendar = eventCalendar
        event.setStartDate(date)
        onSaveAsEvent(event)
    }

    // MARK: Calendars

    /// A calendar of this kind in the user's time zone and language.
    static func calendar(_ identifier: Calendar.Identifier) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = .autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    /// "Hebrew Calendar", in the user's language.
    static func name(_ identifier: Calendar.Identifier) -> String {
        Locale.autoupdatingCurrent.localizedString(for: identifier) ?? "\(identifier)"
    }

    /// `date` as `identifier`'s calendar writes it, e.g. "23 Tishri 5787".
    static func formatted(_ date: Date, in identifier: Calendar.Identifier) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted, calendar: calendar(identifier)))
    }
}

/// A date in another calendar: the date itself first, as it's the answer, and the
/// calendar's name below — two lines in every row, however long either is.
private struct ConvertedDateRow: View {
    let date: String
    let calendar: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: date)
                .font(.body.weight(.semibold))
                .contentTransition(.numericText())
            Text(verbatim: calendar)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contextMenu {
            Button("calc.calendarConverter.copy", systemImage: "doc.on.doc") {
                Platform.copy(date)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
