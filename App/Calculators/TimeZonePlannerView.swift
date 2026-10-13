import SwiftUI

/// The same moment in several cities, with each city's working hours across the
/// day — for calls and meetings across time zones.
struct TimeZonePlannerView: View {
    @AppStorage("plannerTimeZones") private var storedIdentifiers = "America/New_York,Europe/London,Asia/Tokyo"
    @State private var moment = Date.now
    @State private var isAddingZone = false
    @State private var newZone: String?

    private var zones: [TimeZone] {
        [TimeZone.autoupdatingCurrent] + storedIdentifiers.split(separator: ",").compactMap { TimeZone(identifier: String($0)) }
    }

    var body: some View {
        Form {
            Section {
                DateRow(title: "Time Here", date: $moment, includesTime: true)
            }

            Section {
                ForEach(Array(zones.enumerated()), id: \.offset) { index, zone in
                    ZoneRow(zone: zone, moment: moment, isLocal: index == 0)
                }
                .onDelete(perform: remove)
                Button("Add City", systemImage: "plus") { isAddingZone = true }
            } header: {
                Text("Cities")
            } footer: {
                Text("Green hours are 9:00 to 17:00 in each city; the line marks the time above.")
            }
        }
        .navigationTitle("Time Zones")
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

private struct ZoneRow: View {
    let zone: TimeZone
    let moment: Date
    let isLocal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isLocal ? String(localized: "Here") : TimeZonePicker.city(zone.identifier))
                        .font(.headline)
                    Text(offsetText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: moment.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone)))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .fontDesign(.rounded)
            }
            DayStrip(zone: zone, moment: moment)
                .frame(height: 14)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// "+8 h" or "same time", relative to this device.
    private var offsetText: String {
        let difference = zone.secondsFromGMT(for: moment) - TimeZone.autoupdatingCurrent.secondsFromGMT(for: moment)
        let dayText = moment.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: zone))
        guard difference != 0 else { return dayText }
        let hours = Double(difference) / 3600
        let sign = hours > 0 ? "+" : "−"
        return "\(dayText) · \(sign)\(abs(hours).formatted(.number.precision(.fractionLength(0...2)))) h"
    }
}

/// A city's day as 24 hour cells around the chosen moment, working hours in green.
private struct DayStrip: View {
    let zone: TimeZone
    let moment: Date

    var body: some View {
        Canvas { context, size in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            // Twelve hours either side of the moment.
            let cellWidth = size.width / 24
            for slot in 0..<24 {
                let time = moment.addingTimeInterval(Double(slot - 12) * 3600)
                let hour = calendar.component(.hour, from: time)
                let color: Color = (9..<17).contains(hour) ? .green : (7..<22).contains(hour) ? .yellow.opacity(0.6) : .gray.opacity(0.25)
                let rect = CGRect(x: CGFloat(slot) * cellWidth + 0.5, y: 0, width: cellWidth - 1, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
            }
            let marker = CGRect(x: size.width / 2 - 1, y: -2, width: 2, height: size.height + 4)
            context.fill(Path(marker), with: .color(.primary))
        }
        .accessibilityHidden(true)
    }
}
