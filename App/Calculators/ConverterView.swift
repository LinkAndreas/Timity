import SwiftUI
import UIKit

/// Dates as computers keep them: Unix timestamps, ISO 8601 and Julian days.
struct ConverterView: View {
    @State private var date = Date.now
    @State private var input = ""

    var body: some View {
        Form {
            Section {
                TextField("1760262060 or 2025-10-12T09:41:00Z", text: $input)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .monospaced()
                    .onSubmit(read)
                    .onChange(of: input) { read() }
                DateRow(title: "Date", date: $date, includesTime: true)
            } header: {
                Text("Timestamp or Date")
            } footer: {
                Text("Paste a Unix timestamp in seconds or milliseconds, an ISO 8601 date, or a Julian day starting with JD.")
            }

            Section("Converted") {
                CopyRow(title: "Unix Seconds", value: String(Timestamps.unixSeconds(date)))
                CopyRow(title: "Unix Milliseconds", value: String(Timestamps.unixMilliseconds(date)))
                CopyRow(title: "ISO 8601 (UTC)", value: Timestamps.iso8601(date))
                CopyRow(title: "ISO 8601 (Local)", value: Timestamps.iso8601(date, timeZone: .autoupdatingCurrent))
                CopyRow(title: "Julian Day", value: Timestamps.julianDay(date).formatted(.number.precision(.fractionLength(5)).grouping(.never)))
            }
        }
        .navigationTitle("Converter")
    }

    private func read() {
        let text = input.trimmingCharacters(in: .whitespaces)
        if text.uppercased().hasPrefix("JD"), let day = Double(text.dropFirst(2).trimmingCharacters(in: .whitespaces)) {
            date = Timestamps.date(fromJulianDay: day)
        } else if let number = Double(text) {
            date = Timestamps.date(fromUnix: number)
        } else if let parsed = Timestamps.date(fromISO8601: text) {
            date = parsed
        }
    }
}

private struct CopyRow: View {
    let title: LocalizedStringKey
    let value: String
    @State private var copied = 0

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copied += 1
        } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    Text(value)
                        .monospaced()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .textSelection(.enabled)
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .symbolEffect(.bounce, value: copied)
                }
            } label: {
                Text(title)
            }
        }
        .tint(.primary)
        .sensoryFeedback(.success, trigger: copied)
        .accessibilityHint(Text("Copies the value"))
    }
}
