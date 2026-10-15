import SwiftUI

/// The same moment in several cities — for calls and meetings across time zones.
/// Any city's time can be changed and the others follow; each city says whether
/// it's working hours there, and the times that suit everyone are listed.
struct TimeZonePlannerView: View {
    @AppStorage("plannerTimeZones") private var storedIdentifiers = "America/New_York,Europe/London,Asia/Tokyo"
    @State private var moment = Date.now
    @State private var isAddingZone = false
    @State private var newZone: String?

    private var zones: [TimeZone] {
        [TimeZone.autoupdatingCurrent] + storedIdentifiers.split(separator: ",").compactMap { TimeZone(identifier: String($0)) }
    }

    var body: some View {
        SideBySideForm {
            Section {
                DateRow(title: "calc.timeZonePlanner.here", date: $moment, includesTime: true)
                Slider(value: minuteOfDay, in: 0...(24 * 60 - 15), step: 15) {
                    Text("calc.timeZonePlanner.timeOfDay")
                } minimumValueLabel: {
                    Text(verbatim: Self.clock(minutes: 0))
                } maximumValueLabel: {
                    Text(verbatim: Self.clock(minutes: 24 * 60 - 15))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("calc.timeZonePlanner.when")
            } footer: {
                Text("calc.timeZonePlanner.pickATimeHereDrag")
            }
        } trailing: {
            if zones.count > 1 {
                meetingSection
            }

            Section {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                    ZoneRow(zone: zone, moment: $moment, isLocal: index == 0)
                        .deleteDisabled(index == 0)
                }
                .onDelete(perform: remove)
                Button("calc.timeZonePlanner.addCity", systemImage: "plus") { isAddingZone = true }
            } header: {
                Text("calc.timeZonePlanner.cities")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    DayPartLegend()
                    Text("calc.timeZonePlanner.eachBarIsThatCitys")
                }
            }
        }
        .navigationTitle("common.timeZones")
        .sheet(isPresented: $isAddingZone, onDismiss: addPickedZone) {
            NavigationStack {
                TimeZonePicker(selection: $newZone)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) { isAddingZone = false }
                        }
                    }
            }
            .onChange(of: newZone) { isAddingZone = false }
        }
    }

    /// The times on the chosen day that fall in working hours in every city.
    private var meetingSection: some View {
        let windows = MeetingPlanner.windows(on: moment, zones: zones)

        return Section {
            if windows.isEmpty {
                Label("calc.timeZonePlanner.noTimeOnThisDay", systemImage: "calendar.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(windows, id: \.self) { window in
                    Button {
                        withAnimation { moment = window.start }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: Self.range(window, in: .autoupdatingCurrent))
                                    .font(.headline.monospacedDigit())
                                Text(verbatim: zones.dropFirst()
                                    .map { "\(TimeZonePicker.city($0.identifier)) \(Self.range(window, in: $0))" }
                                    .joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.tint)
                                .accessibilityHidden(true)
                        }
                    }
                    .tint(.primary)
                    .accessibilityHint(Text("calc.timeZonePlanner.showsThisTimeInEvery"))
                }
            }
        } header: {
            Text("calc.timeZonePlanner.bestTimeToMeet")
        } footer: {
            Text("calc.timeZonePlanner.timesHereWhenItsWorking")
        }
    }

    /// The chosen moment's time of day here, in minutes, for the slider.
    private var minuteOfDay: Binding<Double> {
        Binding(
            get: {
                let parts = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: moment)
                return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            },
            set: { minutes in
                let calendar = Calendar.autoupdatingCurrent
                let start = calendar.startOfDay(for: moment)
                moment = calendar.date(byAdding: .minute, value: Int(minutes), to: start) ?? moment
            }
        )
    }

    /// "0:00" or "12 AM", as the locale writes times.
    private static func clock(minutes: Int) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let time = calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: .now)) ?? .now
        return time.formatted(date: .omitted, time: .shortened)
    }

    /// "15:00 – 17:00" in `zone`.
    private static func range(_ interval: DateInterval, in zone: TimeZone) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone)
        return "\(interval.start.formatted(style)) – \(interval.end.formatted(style))"
    }

    private func remove(_ offsets: IndexSet) {
        // The first row is this device's time zone and stays.
        var identifiers = storedIdentifiers.split(separator: ",").map(String.init)
        for offset in offsets.sorted(by: >) where offset > 0 && offset - 1 < identifiers.count {
            identifiers.remove(at: offset - 1)
        }
        storedIdentifiers = identifiers.joined(separator: ",")
    }

    private func addPickedZone() {
        guard let identifier = newZone else { return }
        var identifiers = storedIdentifiers.split(separator: ",").map(String.init)
        if !identifiers.contains(identifier) { identifiers.append(identifier) }
        storedIdentifiers = identifiers.joined(separator: ",")
        newZone = nil
    }
}

/// One city: its name, its own time to change, what part of the day it is there,
/// how far ahead or behind it is, and its day as a bar.
private struct ZoneRow: View {
    let zone: TimeZone
    @Binding var moment: Date
    let isLocal: Bool

    var body: some View {
        let part = MeetingPlanner.dayPart(at: moment, in: zone)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: isLocal
                        ? "\(String(localized: "calc.timeZonePlanner.here")) · \(TimeZonePicker.city(zone.identifier))"
                        : TimeZonePicker.city(zone.identifier))
                        .font(.headline)
                    Label(part.title, systemImage: part.systemImage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(part.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    // The city's own time: changing it moves the moment for every city.
                    DatePicker(
                        String(localized: "calc.timeZonePlanner.timeIn \(TimeZonePicker.city(zone.identifier))"),
                        selection: $moment,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .environment(\.timeZone, zone)
                    Text(verbatim: relationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            DayStrip(zone: zone, moment: moment)
        }
        .padding(.vertical, 4)
    }

    /// "8 h ahead · tomorrow", or for this device the date.
    private var relationText: String {
        let date = moment.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day().month(.abbreviated))
        guard !isLocal else { return date }
        let offset = MeetingPlanner.offset(of: zone, from: .autoupdatingCurrent, at: moment)
        let amount = Duration.seconds(abs(offset)).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        let difference = offset == 0
            ? String(localized: "calc.timeZonePlanner.sameTime")
            : offset > 0 ? String(localized: "calc.timeZonePlanner.ahead \(amount)") : String(localized: "calc.timeZonePlanner.behind \(amount)")
        switch MeetingPlanner.dayDifference(of: zone, from: .autoupdatingCurrent, at: moment) {
        case 1: return "\(difference) · \(String(localized: "common.tomorrow"))"
        case -1: return "\(difference) · \(String(localized: "common.yesterday"))"
        default: return difference
        }
    }
}

nonisolated extension MeetingPlanner.DayPart {
    var title: LocalizedStringKey {
        switch self {
        case .working: "calc.timeZonePlanner.workingHours"
        case .morning: "calc.timeZonePlanner.morning"
        case .evening: "calc.timeZonePlanner.evening"
        case .night: "calc.timeZonePlanner.night"
        }
    }

    var systemImage: String {
        switch self {
        case .working: "briefcase.fill"
        case .morning: "sunrise.fill"
        case .evening: "sunset.fill"
        case .night: "moon.zzz.fill"
        }
    }

    var color: Color {
        switch self {
        case .working: .green
        case .morning, .evening: .orange
        case .night: .secondary
        }
    }

    /// The bar's colour for an hour in this part of the day.
    var stripColor: Color {
        switch self {
        case .working: .green
        case .morning, .evening: .orange.opacity(0.55)
        case .night: .gray.opacity(0.25)
        }
    }
}

/// What the bar's colours mean.
private struct DayPartLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(.working)
            item(.evening, title: "calc.timeZonePlanner.morningEvening")
            item(.night)
        }
        .font(.caption)
    }

    private func item(_ part: MeetingPlanner.DayPart, title: LocalizedStringKey? = nil) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(part.stripColor)
                .frame(width: 12, height: 8)
            Text(title ?? part.title)
        }
    }
}

/// A city's day from midnight to midnight as 24 hour cells coloured by the part
/// of the day, the chosen moment as a line, and every six hours labelled.
private struct DayStrip: View {
    let zone: TimeZone
    let moment: Date

    var body: some View {
        VStack(spacing: 2) {
            Canvas { context, size in
                let cellWidth = size.width / 24
                for hour in 0..<24 {
                    let rect = CGRect(x: CGFloat(hour) * cellWidth + 0.5, y: 0, width: cellWidth - 1, height: size.height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(MeetingPlanner.DayPart(hour: hour).stripColor))
                }
                let x = size.width * markerFraction
                context.fill(Path(roundedRect: CGRect(x: x - 1, y: -2, width: 2, height: size.height + 4), cornerRadius: 1), with: .color(.primary))
            }
            .frame(height: 12)
            GeometryReader { proxy in
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(verbatim: "\(hour)")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: proxy.size.width * CGFloat(hour) / 24, y: proxy.size.height / 2)
                }
            }
            .frame(height: 11)
        }
        .accessibilityHidden(true)
    }

    /// Where the moment falls in the city's day, from 0 at midnight to 1.
    private var markerFraction: CGFloat {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: moment)
        return CGFloat((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / (24 * 60)
    }
}
