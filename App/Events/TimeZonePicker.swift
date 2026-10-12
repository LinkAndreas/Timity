import SwiftUI

/// Picks the time zone an event happens in, searchable by city and name.
struct TimeZonePicker: View {
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List {
            Section {
                row(identifier: nil, title: String(localized: "Local Time"), detail: name(TimeZone.autoupdatingCurrent))
            }
            Section {
                ForEach(results, id: \.self) { identifier in
                    if let zone = TimeZone(identifier: identifier) {
                        row(identifier: identifier, title: Self.city(identifier), detail: name(zone))
                    }
                }
            } footer: {
                Text("The event's time is shown as it reads there, and repeats keep that time.")
            }
        }
        .navigationTitle("Time Zone")
        .searchable(text: $searchText, prompt: "City or Time Zone")
    }

    private func row(identifier: String?, title: String, detail: String) -> some View {
        Button {
            selection = identifier
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selection == identifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Selected")
                }
            }
        }
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
