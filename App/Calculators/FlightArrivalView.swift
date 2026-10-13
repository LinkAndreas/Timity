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
            Section("Departure") {
                Button { choosing = .origin } label: {
                    LabeledContent("From", value: TimeZonePicker.city(originIdentifier))
                }
                .tint(.primary)
                DatePicker("Leaves", selection: $departure)
                    .environment(\.timeZone, origin)
            }

            Section {
                Stepper(value: $hours, in: 0...24) {
                    LabeledContent("Hours", value: hours.formatted())
                }
                Stepper(value: $minutes, in: 0...55, step: 5) {
                    LabeledContent("Minutes", value: minutes.formatted())
                }
            } header: {
                Text("Flight Time")
            } footer: {
                Text("The time in the air, as on your ticket.")
            }

            Section("Arrival") {
                Button { choosing = .destination } label: {
                    LabeledContent("To", value: TimeZonePicker.city(destinationIdentifier))
                }
                .tint(.primary)
            }
        } trailing: {
            Section {
                ResultHero(color: .cyan) {
                    Text("Lands at")
                        .font(.title3.weight(.semibold))
                        .opacity(0.9)
                    Text(verbatim: result.arrival.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: destination)))
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
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
        .navigationTitle("Flight Arrival")
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
        }
    }

    /// "Next day · 6 h behind".
    private func summary(_ result: FlightArrival.Result) -> String {
        var parts: [String] = []
        switch result.dayChange {
        case 0: break
        case 1: parts.append(String(localized: "Next day"))
        case -1: parts.append(String(localized: "Day before"))
        default: parts.append(String(localized: "\(result.dayChange) days later"))
        }
        let hours = Double(abs(result.timeDifference)) / 3600
        let amount = hours.formatted(.number.precision(.fractionLength(0...2)))
        if result.timeDifference > 0 { parts.append(String(localized: "\(amount) h ahead")) }
        if result.timeDifference < 0 { parts.append(String(localized: "\(amount) h behind")) }
        return parts.joined(separator: " · ")
    }
}
