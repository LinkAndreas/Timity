import SwiftUI

/// When a flight lands, in the time where it lands.
struct FlightArrivalView: View {
    @AppStorage("flightOrigin") private var originIdentifier = TimeZone.autoupdatingCurrent.identifier
    @AppStorage("flightDestination") private var destinationIdentifier = "America/New_York"
    @State private var departure = Calendar.autoupdatingCurrent.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    @State private var hours = 9
    @State private var minutes = 0
    @State private var choosing: End?

    private enum End: Identifiable {
        case origin, destination
        var id: Self { self }
    }

    var body: some View {
        let origin = TimeZone(identifier: originIdentifier) ?? .autoupdatingCurrent
        let destination = TimeZone(identifier: destinationIdentifier) ?? .autoupdatingCurrent
        let result = FlightArrival.arrival(
            departure: departure, from: origin, duration: TimeInterval(hours * 3600 + minutes * 60), to: destination
        )

        SideBySideForm {
            Section("calc.flightArrival.departure") {
                Button { choosing = .origin } label: {
                    LabeledContent("common.from") {
                        CityChoice(name: TimeZonePicker.city(originIdentifier))
                    }
                }
                .tint(.primary)
                DateRow(title: "calc.flightArrival.leaves", date: $departure, includesTime: true)
                    .environment(\.timeZone, origin)
            }

            Section {
                NumberStepperRow(title: "common.hours", value: $hours, range: 0...24, valueText: hours.formatted())
                NumberStepperRow(title: "common.minutes", value: $minutes, range: 0...59, step: 5, valueText: minutes.formatted())
            } header: {
                Text("calc.flightArrival.flightTime")
            } footer: {
                Text("calc.flightArrival.theTimeInTheAir")
            }

            Section("calc.flightArrival.arrival") {
                Button { choosing = .destination } label: {
                    LabeledContent("common.to") {
                        CityChoice(name: TimeZonePicker.city(destinationIdentifier))
                    }
                }
                .tint(.primary)
            }
        } trailing: {
            Section {
                ResultHero(color: .cyan) {
                    Text("calc.flightArrival.landsAt")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(verbatim: result.arrival.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: destination)))
                        .scaledFont(size: 64, weight: .heavy, design: .rounded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(verbatim: result.arrival.formatted(Date.FormatStyle(timeZone: destination).weekday(.wide).day().month(.wide)))
                        .font(.headline)
                    if result.dayChange != 0 || result.timeDifference != 0 {
                        Text(summary(result))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
                .animation(.snappy, value: result)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("common.flightArrival")
        .sheet(item: $choosing) { end in
            NavigationStack {
                TimeZonePicker(selection: Binding(
                    get: { end == .origin ? originIdentifier : destinationIdentifier },
                    set: { picked in
                        let identifier = picked ?? TimeZone.autoupdatingCurrent.identifier
                        if end == .origin { originIdentifier = identifier } else { destinationIdentifier = identifier }
                        choosing = nil
                    }
                ))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { choosing = nil }
                    }
                }
            }
            .macSheetSize(width: 440, height: 560)
        }
    }

    /// "Next day · local time 6 h behind": whose clock is behind, said.
    private func summary(_ result: FlightArrival.Result) -> String {
        var parts: [String] = []
        switch result.dayChange {
        case 0: break
        case 1: parts.append(String(localized: "calc.flightArrival.nextDay"))
        case -1: parts.append(String(localized: "calc.flightArrival.dayBefore"))
        default: parts.append(String(localized: "calc.flightArrival.daysLater \(result.dayChange)"))
        }
        let hours = Double(abs(result.timeDifference)) / 3600
        let amount = hours.formatted(.number.precision(.fractionLength(0...2)))
        if result.timeDifference > 0 { parts.append(String(localized: "calc.flightArrival.localTimeHAhead \(amount)")) }
        if result.timeDifference < 0 { parts.append(String(localized: "calc.flightArrival.localTimeHBehind \(amount)")) }
        return parts.joined(separator: " · ")
    }
}

/// A chosen city, with the chevron that shows the row opens a list to pick another.
private struct CityChoice: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}
