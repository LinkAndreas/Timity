import SwiftUI

/// Picks the time zone an event happens in, searchable by city and name.
struct TimeZonePicker: View {
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                TimeZoneRow(
                    title: String(localized: "common.localTime"),
                    detail: name(TimeZone.autoupdatingCurrent),
                    isChosen: selection == nil,
                    choose: { choose(nil) }
                )
            }
            Section {
                ForEach(results, id: \.self) { identifier in
                    if let zone = TimeZone(identifier: identifier) {
                        TimeZoneRow(
                            title: Self.city(identifier),
                            detail: name(zone),
                            isChosen: selection == identifier,
                            choose: { choose(identifier) }
                        )
                    }
                }
            } footer: {
                Text("events.theEventsTimeIsShown")
            }
        }
        .navigationTitle("common.timeZone")
        .searchable(text: $searchText, prompt: "events.cityOrTimeZone")
    }

    /// Takes the zone, or the local time for nil, and closes the picker.
    private func choose(_ identifier: String?) {
        selection = identifier
        dismiss()
    }

    private var results: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let all = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") && !$0.hasPrefix("Etc/") }
        guard !query.isEmpty else { return all.sorted { Self.city($0) < Self.city($1) } }
        return all
            .filter { identifier in
                Self.city(identifier).localizedStandardContains(query)
                    || identifier.localizedStandardContains(query)
                    || (TimeZone(identifier: identifier).map(name) ?? "").localizedStandardContains(query)
            }
            .sorted { Self.city($0) < Self.city($1) }
    }

    private func name(_ zone: TimeZone) -> String {
        Self.name(for: zone)
    }

    /// "Tokyo" from "Asia/Tokyo".
    static func city(_ identifier: String) -> String {
        (identifier.split(separator: "/").last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
    }

    /// "Tokyo (Japan Standard Time)".
    static func name(for zone: TimeZone) -> String {
        let generic = zone.localizedName(for: .generic, locale: .autoupdatingCurrent) ?? zone.identifier
        return "\(city(zone.identifier)) (\(generic))"
    }
}

/// A zone's city and name, ticked when it's the one chosen.
private struct TimeZoneRow: View {
    let title: String
    let detail: String
    let isChosen: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack {
                // The label colours themselves: a button's `.primary` and `.secondary` derive
                // from the tint, which turned every row the accent colour.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                if isChosen {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("events.selected2")
                }
            }
        }
    }
}
