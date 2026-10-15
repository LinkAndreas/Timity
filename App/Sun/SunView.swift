import SwiftUI
import UIKit

/// The Astronomy tab: sunrise, sunset, golden and blue hour and twilight for the
/// current location or a chosen place, and the Moon's phases, rise and set.
struct SunView: View {
    let location: SunPlaceModel
    /// Places matching a name, to add one.
    let searchPlaces: (String) async -> [Place]
    @State private var date = Date.now
    @SceneStorage("skySection") private var section = SkySection.sun
    @State private var isChoosingPlace = false
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        NavigationStack {
            // One scroll view for the Sun and the Moon, with the switch at its top: only
            // what's below the switch changes, so the large title stays where it is.
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(spacing: 16) {
                        SkySectionPicker(selection: $section)
                        // The Moon's phases need no place; the Sun's day does.
                        if section == .moon || location.place != nil {
                            SkyDayPicker(date: $date)
                        }
                        Group {
                            switch section {
                            case .sun:
                                if let place = location.place {
                                    SunContent(place: place, date: date, now: context.date)
                                } else {
                                    placeholder
                                        .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
                                }
                            case .moon:
                                MoonContent(place: location.place, date: $date, now: context.date)
                            }
                        }
                        .transition(.opacity)
                    }
                    .padding()
                    // With the iPhone on its side, the Sun's path and times sit side by side.
                    .frame(maxWidth: verticalSizeClass == .compact && section == .sun ? .infinity : 760)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(location.place?.name ?? String(localized: "common.astronomy"))
            // The title switches between places, as in Weather.
            .toolbarTitleMenu {
                Button {
                    Task { await location.useCurrentLocation() }
                } label: {
                    Label("astronomy.currentLocation", systemImage: location.followsLocation ? "checkmark" : "location.fill")
                }
                ForEach(location.savedPlaces, id: \.self) { place in
                    Button {
                        location.choose(place)
                    } label: {
                        let isShown = !location.followsLocation && location.place.map { $0.isSameSpot(as: place) } == true
                        Label(place.name ?? String(localized: "astronomy.place"), systemImage: isShown ? "checkmark" : "mappin")
                    }
                }
                Divider()
                Button("astronomy.addAPlace", systemImage: "plus") { isChoosingPlace = true }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("astronomy.places", systemImage: location.followsLocation ? "location.fill" : "mappin.and.ellipse") {
                        isChoosingPlace = true
                    }
                    .symbolEffect(.pulse, isActive: location.status == .locating)
                }
            }
            .sheet(isPresented: $isChoosingPlace) {
                PlacePicker(location: location, searchPlaces: searchPlaces)
            }
            .task {
                // Refresh the place each time the tab opens, if it follows the user.
                if location.isAuthorized { await location.locate() }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch location.status {
        case .locating:
            ProgressView("astronomy.findingYourLocation")
        case .denied:
            ContentUnavailableView {
                Label("astronomy.locationAccessIsOff", systemImage: "location.slash")
            } description: {
                Text("astronomy.allowTimityToUseYour")
            } actions: {
                Button("common.openSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glassProminent)
            }
        case .failed:
            ContentUnavailableView {
                Label("astronomy.locationUnavailable", systemImage: "location.slash")
            } description: {
                Text("astronomy.yourLocationCouldntBeFound")
            } actions: {
                Button("common.tryAgain") { Task { await location.useCurrentLocation() } }
                    .buttonStyle(.glassProminent)
            }
        case .idle:
            ContentUnavailableView {
                Label("astronomy.sunriseAndSunset", systemImage: "sun.horizon.fill")
            } description: {
                Text("astronomy.seeWhenTheSunRises")
            } actions: {
                Button("astronomy.useCurrentLocation", systemImage: "location.fill") { Task { await location.useCurrentLocation() } }
                    .buttonStyle(.glassProminent)
                Button("astronomy.chooseAPlace", systemImage: "magnifyingglass") { isChoosingPlace = true }
                    .buttonStyle(.glass)
            }
        }
    }
}

/// The sun's day at a place: its path across the sky and every time.
private struct SunContent: View {
    let place: Place
    let date: Date
    let now: Date

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let sun = SolarCalculator.day(containing: date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
        let yesterday = SolarCalculator.day(
            containing: date.addingTimeInterval(-86_400),
            latitude: place.latitude,
            longitude: place.longitude,
            timeZone: place.timeZone
        )
        let time = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: place.timeZone)

        // With the iPhone on its side, its path beside the times.
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: 16) {
                SunPathCard(place: place, day: sun, date: date, now: now)
                VStack(spacing: 16) {
                    details(sun: sun, yesterday: yesterday, time: time)
                }
            }
        } else {
            VStack(spacing: 16) {
                SunPathCard(place: place, day: sun, date: date, now: now)
                details(sun: sun, yesterday: yesterday, time: time)
            }
        }
    }

    /// The times, twilight and seasons below the sun's path.
    @ViewBuilder
    private func details(sun: SolarDay, yesterday: SolarDay, time: Date.FormatStyle) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            SunTile(title: "common.sunrise", systemImage: "sunrise.fill", tint: .orange, value: sun.sunrise?.formatted(time), detail: polarDetail(sun))
            SunTile(title: "common.sunset", systemImage: "sunset.fill", tint: .pink, value: sun.sunset?.formatted(time), detail: polarDetail(sun))
            SunTile(title: "common.daylight", systemImage: "sun.max.fill", tint: .yellow, value: duration(sun.daylight), detail: daylightChange(today: sun, yesterday: yesterday))
            SunTile(title: "astronomy.solarNoon", systemImage: "sun.max.circle.fill", tint: .orange, value: sun.solarNoon.formatted(time), detail: String(localized: "astronomy.sunAtItsHighest"))
            SunTile(
                title: "common.goldenHour",
                systemImage: "camera.filters",
                tint: .orange,
                value: range(sun.goldenHourEveningStart, sun.sunset, time),
                detail: range(sun.sunrise, sun.goldenHourMorningEnd, time).map { String(localized: "astronomy.morning \($0)") }
            )
            SunTile(
                title: "astronomy.blueHour",
                systemImage: "moon.haze.fill",
                tint: .indigo,
                value: range(sun.blueHourEveningStart, sun.civilDusk, time),
                detail: range(sun.civilDawn, sun.blueHourMorningEnd, time).map { String(localized: "astronomy.morning \($0)") }
            )
        }

        Card(title: "astronomy.twilight") {
            VStack(spacing: 10) {
                TwilightRow(title: "astronomy.civil", dawn: sun.civilDawn, dusk: sun.civilDusk, style: time)
                TwilightRow(title: "astronomy.nautical", dawn: sun.nauticalDawn, dusk: sun.nauticalDusk, style: time)
                TwilightRow(title: "astronomy.astronomical", dawn: sun.astronomicalDawn, dusk: sun.astronomicalDusk, style: time)
            }
            Text("astronomy.civilTwilightIsBrightEnough")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        SeasonsCard(place: place, now: now)

        if place.timeZone.identifier != TimeZone.autoupdatingCurrent.identifier {
            Label("astronomy.timesAreShownInThe \(place.name ?? place.timeZone.identifier)", systemImage: "globe")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func polarDetail(_ sun: SolarDay) -> String? {
        switch sun.kind {
        case .polarDay: String(localized: "astronomy.theSunDoesntSetToday")
        case .polarNight: String(localized: "astronomy.theSunDoesntRiseToday")
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
            ? String(localized: "astronomy.longerThanYesterday \(amount)")
            : String(localized: "astronomy.shorterThanYesterday \(amount)")
    }

    private func range(_ start: Date?, _ end: Date?, _ style: Date.FormatStyle) -> String? {
        guard let start, let end else { return nil }
        return Date.IntervalFormatStyle.timeRange(in: style.timeZone).string(from: start, to: end)
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
                Text(verbatim: Date.IntervalFormatStyle.timeRange(in: style.timeZone).string(from: dawn, to: dusk))
                    .monospacedDigit()
            } else {
                Text("astronomy.noneToday")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Where the Sun screen shows: the user's location, a saved place, or a new one
/// found by name.
private struct PlacePicker: View {
    let location: SunPlaceModel
    let searchPlaces: (String) async -> [Place]

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    // One group, the current location first, as in Weather's list of places.
                    Section {
                        Button {
                            Task { await location.useCurrentLocation() }
                            dismiss()
                        } label: {
                            row(String(localized: "astronomy.currentLocation"), detail: nil, systemImage: "location.fill",
                                isChosen: location.followsLocation)
                        }
                        ForEach(location.savedPlaces, id: \.self) { place in
                            Button {
                                location.choose(place)
                                dismiss()
                            } label: {
                                row(place.name ?? "", detail: place.detail ?? place.timeZoneDescription, systemImage: "mappin",
                                    isChosen: !location.followsLocation && location.place.map { $0.isSameSpot(as: place) } == true)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { location.savedPlaces[$0] }.forEach(location.remove)
                        }
                    }
                } else {
                    Section {
                        ForEach(results, id: \.self) { place in
                            Button {
                                location.choose(place)
                                dismiss()
                            } label: {
                                row(place.name ?? "", detail: place.detail ?? place.timeZoneDescription, systemImage: "mappin", isChosen: false)
                            }
                        }
                    }
                }
            }
            // The rows right below the search field, on the sheet's own glass.
            .contentMargins(.top, 8, for: .scrollContent)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .overlay {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty, results.isEmpty, !isSearching {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "astronomy.cityOrPlace")
            .task(id: query) {
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return results = [] }
                isSearching = true
                // Wait for a pause in typing before asking Maps.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = await searchPlaces(trimmed)
                isSearching = false
            }
            .navigationTitle("astronomy.places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, detail: String?, systemImage: String, isChosen: Bool) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            } icon: {
                Image(systemName: systemImage)
            }
            Spacer()
            if isChosen {
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
                    .fontWeight(.semibold)
            }
        }
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

nonisolated private extension Place {
    /// "GMT+1", for places without a region.
    var timeZoneDescription: String {
        timeZone.localizedName(for: .shortGeneric, locale: .autoupdatingCurrent) ?? timeZone.identifier
    }
}
