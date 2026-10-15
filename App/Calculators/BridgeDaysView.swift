import SwiftUI

/// The days of leave that turn public holidays into the longest breaks.
struct BridgeDaysView: View {
    /// Whose public holidays the breaks are built around.
    @Binding var holidayRegion: HolidayRegion?

    @State private var year = Calendar.autoupdatingCurrent.component(.year, from: .now)

    var body: some View {
        let region = holidayRegion ?? HolidayRegion(locale: .autoupdatingCurrent) ?? .unitedStates
        let breaks = BridgeDays.opportunities(in: year, region: region)
            // This year, only breaks still ahead.
            .filter { $0.end >= Calendar.gregorianUTC.startOfDay(for: today) }

        SideBySideForm {
            Section {
                Picker("common.year", selection: $year) {
                    ForEach(thisYear...(thisYear + 2), id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("calc.bridgeDays.publicHolidaysIn", selection: Binding(get: { region }, set: { holidayRegion = $0 })) {
                    ForEach(HolidayRegion.allCases) { region in
                        Text(region.localizedName()).tag(region)
                    }
                }
            } footer: {
                Text("calc.bridgeDays.eachBreakJoinsPublicHolidays")
            }
        } trailing: {
            if breaks.isEmpty {
                ContentUnavailableView("calc.bridgeDays.noBreaksLeft", systemImage: "calendar", description: Text("calc.bridgeDays.tryNextYear"))
                    .listRowBackground(Color.clear)
            } else {
                Section("calc.bridgeDays.bestBreaks") {
                    ForEach(breaks) { opportunity in
                        BreakRow(opportunity: opportunity)
                    }
                }
            }
        }
        .navigationTitle("common.bridgeDays")
    }

    private var today: Date { .now }
    private var thisYear: Int { Calendar.autoupdatingCurrent.component(.year, from: .now) }
}

private struct BreakRow: View {
    let opportunity: BridgeDays.Opportunity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(range)
                    .font(.headline)
                Spacer()
                Text("calc.bridgeDays.daysOff \(opportunity.daysOff)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            Text(opportunity.holidays.formatted(.list(type: .and)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label {
                Text("calc.bridgeDays.takeOffOfLeave \(leave) \(opportunity.leaveDays.count) \(CountdownText.unit(.day, value: opportunity.leaveDays.count))")
            } icon: {
                Image(systemName: "briefcase")
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(timeZone: .gmt).weekday(.abbreviated).day().month(.abbreviated)
    }

    private var range: String {
        "\(opportunity.start.formatted(style)) – \(opportunity.end.formatted(style))"
    }

    private var leave: String {
        opportunity.leaveDays.map { $0.formatted(style) }.formatted(.list(type: .and))
    }
}
