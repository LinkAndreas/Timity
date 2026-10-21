import SwiftUI
import TipKit

/// The Astronomy tab: sunrise, sunset, golden and blue hour and twilight for the
/// current location or a chosen place, and the Moon's phases, rise and set.
struct SunView: View {
    let location: SunPlaceModel
    /// Places matching a name, to add one.
    let searchPlaces: (String) async -> [Place]
    @State private var date = Date.now
    @SceneStorage("skySection") private var section = SkySection.sun
    @State private var isChoosingPlace = false
    @Environment(\.usesResultColumn) private var usesResultColumn

    var body: some View {
        if usesResultColumn {
            SkyColumns(location: location, searchPlaces: searchPlaces, date: $date, section: $section, isChoosingPlace: $isChoosingPlace)
        } else {
            SkySingleView(location: location, searchPlaces: searchPlaces, date: $date, section: $section, isChoosingPlace: $isChoosingPlace)
        }
    }
}

/// The places in the middle column, as in Weather; the sky over the one chosen in the last.
private struct SkyColumns: View {
    let location: SunPlaceModel
    let searchPlaces: (String) async -> [Place]
    @Binding var date: Date
    @Binding var section: SkySection
    @Binding var isChoosingPlace: Bool

    var body: some View {
        PlacePicker(location: location, searchPlaces: searchPlaces, isColumn: true)
            // The Sun or the Moon chosen here, with the places, and shown alone in the last column.
            .safeAreaInset(edge: .top, spacing: 0) {
                SkySectionPicker(selection: $section)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }
            .resultColumn {
                NavigationStack {
                    Sky(location: location, date: $date, section: $section, isSectionChosenElsewhere: true) { isChoosingPlace = true }
                        .navigationTitle(location.place?.name ?? String(localized: "common.astronomy"))
                        .sheet(isPresented: $isChoosingPlace) {
                            PlacePicker(location: location, searchPlaces: searchPlaces)
                                .macSheetSize(width: 440, height: 520)
                        }
                }
            }
            .task {
                // Refresh the place each time Astronomy opens, if it follows the user.
                if location.isAuthorized { await location.locate() }
            }
    }
}

/// The sky in one view, with the places in the title's menu and a sheet.
private struct SkySingleView: View {
    let location: SunPlaceModel
    let searchPlaces: (String) async -> [Place]
    @Binding var date: Date
    @Binding var section: SkySection
    @Binding var isChoosingPlace: Bool

    var body: some View {
        NavigationStack {
            Sky(location: location, date: $date, section: $section) { isChoosingPlace = true }
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
                        .macSheetSize(width: 440, height: 520)
                }
                .task { await SwipeSkyTip.astronomyOpened.donate() }
                .task {
                    // Refresh the place each time the tab opens, if it follows the user.
                    if location.isAuthorized { await location.locate() }
                }
        }
    }
}

/// The day, and the Sun and the Moon over the place shown: side by side where there's room,
/// otherwise one at a time under a switch.
private struct Sky: View {
    let location: SunPlaceModel
    @Binding var date: Date
    @Binding var section: SkySection
    /// Whether the switch between the Sun and the Moon is in the column beside, so this shows the one chosen alone.
    var isSectionChosenElsewhere = false
    /// Opens the list of places.
    let chooseAPlace: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: CGFloat = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(spacing: 16) {
                    if showsSideBySide {
                        SkyDayPicker(date: $date)
                        HStack(alignment: .top, spacing: 20) {
                            SkyColumn(section: .sun) {
                                SunSection(location: location, date: date, now: context.date, inColumn: true, chooseAPlace: chooseAPlace)
                            }
                            SkyColumn(section: .moon) {
                                MoonContent(place: location.place, date: $date, now: context.date)
                            }
                        }
                    } else {
                        if !isSectionChosenElsewhere {
                            SkySectionPicker(selection: $section)
                                #if os(iOS)
                                // A mouse can't swipe; the Mac switches with the control alone.
                                .popoverTip(SwipeSkyTip(), arrowEdge: .top)
                                #endif
                        }
                        // The Moon's phases need no place; the Sun's day does.
                        if section == .moon || location.place != nil {
                            SkyDayPicker(date: $date)
                        }
                        // Over each other while one slides out and the other in: the
                        // Sun keeps to the left, the Moon to the right, as in the switch.
                        ZStack(alignment: .top) {
                            switch section {
                            case .sun:
                                SunSection(location: location, date: date, now: context.date, inColumn: false, chooseAPlace: chooseAPlace)
                                    .motionTransition(.move(edge: .leading).combined(with: .opacity))
                            case .moon:
                                MoonContent(place: location.place, date: $date, now: context.date)
                                    .motionTransition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                        // A sideways swipe switches, as tapping the other half of the switch does.
                        .simultaneousGesture(sectionSwipe)
                    }
                }
                .padding()
                // Wide windows show both; with the iPhone on its side, the Sun's path
                // and times sit side by side.
                .frame(maxWidth: showsSideBySide ? 1200 : verticalSizeClass == .compact && section == .sun ? .infinity : 760)
                .frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
    }

    /// Room for the Sun and the Moon next to each other, as on an iPad in full screen.
    /// An iPhone on its side counts as compact here and keeps the switch.
    private var showsSideBySide: Bool {
        !isSectionChosenElsewhere && horizontalSizeClass == .regular && width >= 820
    }

    private var sectionSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let sideways = value.translation.width
                // Clearly sideways, so scrolling up and down never switches.
                guard abs(sideways) > 60, abs(sideways) > abs(value.translation.height) * 1.5 else { return }
                let next: SkySection = sideways < 0 ? .moon : .sun
                guard next != section else { return }
                withAnimation(.snappy) { section = next }
                SwipeSkyTip().invalidate(reason: .actionPerformed)
            }
    }
}

/// One of the two columns, under its name.
private struct SkyColumn<Content: View>: View {
    let section: SkySection
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(.title2.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// The Sun's day at the place shown, or what's needed before there is one.
private struct SunSection: View {
    let location: SunPlaceModel
    let date: Date
    let now: Date
    /// In a column beside the Moon, as a card level with it.
    let inColumn: Bool
    let chooseAPlace: () -> Void

    var body: some View {
        if let place = location.place {
            SunContent(place: place, date: date, now: now)
        } else if inColumn {
            // A card at the column's top, level with the Moon's beside it.
            SkyPlaceholder(location: location, chooseAPlace: chooseAPlace)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.background.secondary, in: .rect(cornerRadius: 24, style: .continuous))
        } else {
            SkyPlaceholder(location: location, chooseAPlace: chooseAPlace)
                .containerRelativeFrame(.vertical) { height, _ in height * 0.7 }
        }
    }
}

/// Finding the location, why it can't be, or the ways to choose a place.
private struct SkyPlaceholder: View {
    let location: SunPlaceModel
    let chooseAPlace: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch location.status {
        case .locating:
            ProgressView("astronomy.findingYourLocation")
        case .denied:
            ContentUnavailableView {
                Label("astronomy.locationAccessIsOff", systemImage: "location.slash")
            } description: {
                #if os(macOS)
                Text("astronomy.allowTimityToUseYour.mac")
                #else
                Text("astronomy.allowTimityToUseYour")
                #endif
            } actions: {
                Button {
                    if let url = Platform.appSettingsURL { openURL(url) }
                } label: {
                    PlaceholderActionLabel("common.openSettings", systemImage: "gear")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        case .failed:
            ContentUnavailableView {
                Label("astronomy.locationUnavailable", systemImage: "location.slash")
            } description: {
                Text("astronomy.yourLocationCouldntBeFound")
            } actions: {
                Button { Task { await location.useCurrentLocation() } } label: {
                    PlaceholderActionLabel("common.tryAgain", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        case .idle:
            ContentUnavailableView {
                Label("astronomy.sunriseAndSunset", systemImage: "sun.horizon.fill")
            } description: {
                Text("astronomy.seeWhenTheSunRises")
            } actions: {
                // One clear first step, and the other way in as a quieter link below it,
                // as on the empty Events list.
                VStack(spacing: 14) {
                    Button { Task { await location.useCurrentLocation() } } label: {
                        PlaceholderActionLabel("astronomy.useCurrentLocation", systemImage: "location.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Button(action: chooseAPlace) {
                        Label("astronomy.chooseAPlace", systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                }
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
                    SunDetails(place: place, sun: sun, yesterday: yesterday, time: time, now: now)
                }
            }
        } else {
            VStack(spacing: 16) {
                SunPathCard(place: place, day: sun, date: date, now: now)
                SunDetails(place: place, sun: sun, yesterday: yesterday, time: time, now: now)
            }
        }
    }
}

/// The times, twilight and seasons below the sun's path.
private struct SunDetails: View {
    let place: Place
    let sun: SolarDay
    let yesterday: SolarDay
    let time: Date.FormatStyle
    let now: Date

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], spacing: 12) {
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
                // All of it, on as many lines as it needs: German ran past two.
                .fixedSize(horizontal: false, vertical: true)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                // On one line, a little smaller where a long name needs it — "Sonnenhöchststand" —
                // so every tile is as tall as the others; at the largest sizes it wraps instead.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
            Text(value ?? "—")
                .font(.title2.weight(.bold).monospacedDigit())
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // Room for two lines whether there's a detail or not, so tiles side by side
            // are the same height; the grid doesn't stretch them to match.
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
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
    /// The middle column of a three-column window rather than a sheet: it stays open after a choice.
    var isColumn = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if isColumn {
            PlacesList(location: location, searchPlaces: searchPlaces, searchesAtTop: true) {}
        } else {
            NavigationStack {
                PlacesList(location: location, searchPlaces: searchPlaces) { dismiss() }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) { dismiss() }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// The current location and the saved places, or the places found for what's searched.
private struct PlacesList: View {
    let location: SunPlaceModel
    let searchPlaces: (String) async -> [Place]
    /// On the Mac, the search field at the top of the list, as in a column of the window, rather
    /// than at the toolbar's far end.
    var searchesAtTop = false
    /// After a place is chosen, as to close the sheet it's in.
    let onChoice: () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearching = false

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                // One group, the current location first, as in Weather's list of places.
                Section {
                    Button {
                        Task { await location.useCurrentLocation() }
                        choose()
                    } label: {
                        PlaceRow(title: String(localized: "astronomy.currentLocation"), detail: nil, systemImage: "location.fill",
                            isChosen: location.followsLocation)
                    }
                    ForEach(location.savedPlaces, id: \.self) { place in
                        Button {
                            location.choose(place)
                            choose()
                        } label: {
                            PlaceRow(title: place.name ?? "", detail: place.detail ?? place.timeZoneDescription, systemImage: "mappin",
                                isChosen: !location.followsLocation && location.place.map { $0.isSameSpot(as: place) } == true)
                        }
                        .macDeleteMenu { location.remove(place) }
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
                            choose()
                        } label: {
                            PlaceRow(title: place.name ?? "", detail: place.detail ?? place.timeZoneDescription, systemImage: "mappin", isChosen: false)
                        }
                    }
                }
            }
        }
        // The rows right below the search field, on the sheet's own glass.
        .contentMargins(.top, 8, for: .scrollContent)
        .compactSectionSpacing()
        .scrollContentBackground(.hidden)
        .overlay {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty, results.isEmpty {
                // Maps can take a moment: a spinner, so the empty list doesn't read as no results.
                if isSearching {
                    ProgressView()
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .modifier(PlacesSearchField(query: $query, isFocused: $isSearchFocused, isAtTop: searchesAtTop))
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
        .inlineNavigationTitle()
    }

    /// The search starts over for the next time, and whoever shows the list hears of the choice.
    private func choose() {
        query = ""
        onChoice()
    }
}

/// A place, with its region or time zone below, ticked when it's the one shown.
private struct PlaceRow: View {
    let title: String
    let detail: String?
    let systemImage: String
    let isChosen: Bool

    var body: some View {
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

/// Where places are searched: atop a column of the Mac's window, otherwise the system's own field.
private struct PlacesSearchField: ViewModifier {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    let isAtTop: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        if isAtTop {
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    MacSearchField(text: $query, isFocused: isFocused, prompt: "astronomy.cityOrPlace")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
        } else {
            content.pullDownSearchable(text: $query, prompt: "astronomy.cityOrPlace", alwaysShown: true)
        }
        #else
        content.pullDownSearchable(text: $query, prompt: "astronomy.cityOrPlace", alwaysShown: true)
        #endif
    }
}
