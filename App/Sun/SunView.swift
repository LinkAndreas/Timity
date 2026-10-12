import SwiftUI
import UIKit

/// Sunrise, sunset, golden and blue hour and twilight for the current location.
struct SunView: View {
    @State private var location = LocationProvider()
    @State private var date = Date.now
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Group {
                if let place = location.place {
                    TimelineView(.everyMinute) { context in
                        SunContent(place: place, date: $date, now: context.date)
                    }
                } else {
                    placeholder
                }
            }
            .navigationTitle(location.place?.name ?? String(localized: "Sun"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Current Location", systemImage: "location.fill") {
                        location.locate()
                    }
                    .symbolEffect(.pulse, isActive: location.status == .locating)
                }
            }
            .task {
                // Refresh the place each time the tab opens, if allowed.
                if location.isAuthorized { location.locate() }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch location.status {
        case .locating:
            ProgressView("Finding Your Location…")
        case .denied:
            ContentUnavailableView {
                Label("Location Access Is Off", systemImage: "location.slash")
            } description: {
                Text("Allow Timity to use your location in Settings to see sunrise and sunset where you are.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glassProminent)
            }
        case .failed:
            ContentUnavailableView {
                Label("Location Unavailable", systemImage: "location.slash")
            } description: {
                Text("Your location couldn't be found. Check that you're connected and try again.")
            } actions: {
                Button("Try Again") { location.locate() }
                    .buttonStyle(.glassProminent)
            }
        case .idle:
            ContentUnavailableView {
                Label("Sunrise and Sunset", systemImage: "sun.horizon.fill")
            } description: {
                Text("See when the sun rises and sets, golden and blue hour, and twilight where you are.")
            } actions: {
                Button("Use Current Location", systemImage: "location.fill") { location.locate() }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}

/// The sun's day at a place: its path across the sky and every time.
private struct SunContent: View {
    let place: LocationProvider.Place
    @Binding var date: Date
    let now: Date

    var body: some View {
        let sun = SolarCalculator.day(containing: date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
        let yesterday = SolarCalculator.day(
            containing: date.addingTimeInterval(-86_400),
            latitude: place.latitude,
            longitude: place.longitude,
            timeZone: place.timeZone
        )
        let time = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: place.timeZone)

        ScrollView {
            VStack(spacing: 16) {
                // The day shown, in the content rather than beside the large title.
                HStack {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    if !Calendar.autoupdatingCurrent.isDateInToday(date) {
                        Button("Today") {
                            withAnimation { date = .now }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .transition(.opacity)
                    }
                }
                .animation(.snappy, value: Calendar.autoupdatingCurrent.isDateInToday(date))

                SunPathCard(place: place, day: sun, date: date, now: now)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    SunTile(title: "Sunrise", systemImage: "sunrise.fill", tint: .orange, value: sun.sunrise?.formatted(time), detail: polarDetail(sun))
                    SunTile(title: "Sunset", systemImage: "sunset.fill", tint: .pink, value: sun.sunset?.formatted(time), detail: polarDetail(sun))
                    SunTile(title: "Daylight", systemImage: "sun.max.fill", tint: .yellow, value: duration(sun.daylight), detail: daylightChange(today: sun, yesterday: yesterday))
                    SunTile(title: "Solar Noon", systemImage: "sun.max.circle.fill", tint: .orange, value: sun.solarNoon.formatted(time), detail: String(localized: "Sun at its highest"))
                    SunTile(
                        title: "Golden Hour",
                        systemImage: "camera.filters",
                        tint: .orange,
                        value: range(sun.goldenHourEveningStart, sun.sunset, time),
                        detail: range(sun.sunrise, sun.goldenHourMorningEnd, time).map { String(localized: "Morning \($0)") }
                    )
                    SunTile(
                        title: "Blue Hour",
                        systemImage: "moon.haze.fill",
                        tint: .indigo,
                        value: range(sun.blueHourEveningStart, sun.civilDusk, time),
                        detail: range(sun.civilDawn, sun.blueHourMorningEnd, time).map { String(localized: "Morning \($0)") }
                    )
                }

                Card(title: "Twilight") {
                    VStack(spacing: 10) {
                        TwilightRow(title: "Civil", dawn: sun.civilDawn, dusk: sun.civilDusk, style: time)
                        TwilightRow(title: "Nautical", dawn: sun.nauticalDawn, dusk: sun.nauticalDusk, style: time)
                        TwilightRow(title: "Astronomical", dawn: sun.astronomicalDawn, dusk: sun.astronomicalDusk, style: time)
                    }
                    Text("Civil twilight is bright enough to be outside without light; at the end of astronomical twilight the sky is fully dark.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                MoonCard(place: place, date: date, now: now, time: time)
                SeasonsCard(place: place, now: now)

                if place.timeZone.identifier != TimeZone.autoupdatingCurrent.identifier {
                    Label("Times are shown in the local time of \(place.name ?? place.timeZone.identifier).", systemImage: "globe")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func polarDetail(_ sun: SolarDay) -> String? {
        switch sun.kind {
        case .polarDay: String(localized: "The sun doesn't set today")
        case .polarNight: String(localized: "The sun doesn't rise today")
        case .normal: nil
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func daylightChange(today: SolarDay, yesterday: SolarDay) -> String? {
        let change = today.daylight - yesterday.daylight
        guard today.kind == .normal, abs(change) >= 1 else { return nil }
        let amount = Duration.seconds(abs(change)).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
        return change > 0
            ? String(localized: "\(amount) longer than yesterday")
            : String(localized: "\(amount) shorter than yesterday")
    }

    private func range(_ start: Date?, _ end: Date?, _ style: Date.FormatStyle) -> String? {
        guard let start, let end else { return nil }
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}

private struct SunTile: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let value: String?
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
            Text(value ?? "—")
                .font(.title2.weight(.bold).monospacedDigit())
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TwilightRow: View {
    let title: LocalizedStringKey
    let dawn: Date?
    let dusk: Date?
    let style: Date.FormatStyle

    var body: some View {
        LabeledContent(title) {
            if let dawn, let dusk {
                Text("\(dawn.formatted(style)) – \(dusk.formatted(style))")
                    .monospacedDigit()
            } else {
                Text("None today")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
