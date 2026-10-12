import SwiftUI

/// The Moon on the chosen day: its phase and light, when it rises and sets, and
/// when the next phases come.
struct MoonCard: View {
    let place: LocationProvider.Place
    let date: Date
    let now: Date
    let time: Date.FormatStyle

    var body: some View {
        let calendar = placeCalendar
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        // Today's Moon as it is now; another day's at noon.
        let moment = calendar.isDate(now, inSameDayAs: date) ? now : dayStart.addingTimeInterval(12 * 3600)
        let moon = Astronomy.moon(at: moment)
        let times = Astronomy.moonTimes(dayStart: dayStart, dayEnd: dayEnd, latitude: place.latitude, longitude: place.longitude)
        let phases = Astronomy.PrincipalPhase.allCases
            .map { ($0, Astronomy.next($0, after: moment)) }
            .sorted { $0.1 < $1.1 }

        Card(title: "Moon") {
            HStack(spacing: 16) {
                Image(systemName: moon.phase.symbolName)
                    .font(.system(size: 54))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.name(moon.phase))
                        .font(.title3.weight(.semibold))
                    Text("\(moon.illumination.formatted(.percent.precision(.fractionLength(0)))) lit · \(Int(moon.age.rounded())) days old")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 10) {
                LabeledContent("Moonrise", value: times.rise?.formatted(time) ?? String(localized: "None today"))
                LabeledContent("Moonset", value: times.set?.formatted(time) ?? String(localized: "None today"))
                Divider()
                ForEach(phases, id: \.0) { phase, when in
                    LabeledContent {
                        Text(when, format: Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: place.timeZone))
                            .monospacedDigit()
                    } label: {
                        Label {
                            Text(Self.name(phase))
                        } icon: {
                            Image(systemName: Self.symbol(phase))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
        }
    }

    private var placeCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = place.timeZone
        return calendar
    }

    static func name(_ phase: Astronomy.MoonPhase) -> LocalizedStringKey {
        switch phase {
        case .newMoon: "New Moon"
        case .waxingCrescent: "Waxing Crescent"
        case .firstQuarter: "First Quarter"
        case .waxingGibbous: "Waxing Gibbous"
        case .fullMoon: "Full Moon"
        case .waningGibbous: "Waning Gibbous"
        case .lastQuarter: "Last Quarter"
        case .waningCrescent: "Waning Crescent"
        }
    }

    static func name(_ phase: Astronomy.PrincipalPhase) -> LocalizedStringKey {
        switch phase {
        case .newMoon: "New Moon"
        case .firstQuarter: "First Quarter"
        case .fullMoon: "Full Moon"
        case .lastQuarter: "Last Quarter"
        }
    }

    static func symbol(_ phase: Astronomy.PrincipalPhase) -> String {
        switch phase {
        case .newMoon: "moonphase.new.moon"
        case .firstQuarter: "moonphase.first.quarter"
        case .fullMoon: "moonphase.full.moon"
        case .lastQuarter: "moonphase.last.quarter"
        }
    }
}

/// The next equinox or solstice, and the next time the clocks change.
struct SeasonsCard: View {
    let place: LocationProvider.Place
    let now: Date

    var body: some View {
        let next = Astronomy.nextSeason(after: now)
        let change = Astronomy.nextClockChange(after: now, in: place.timeZone)
        let style = Date.FormatStyle(date: .long, time: .shortened, timeZone: place.timeZone)

        Card(title: "Seasons") {
            VStack(spacing: 10) {
                LabeledContent {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(next.date, format: style)
                        Text(relative(next.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.name(next.season))
                        Text(beginning(next.season))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let change {
                    Divider()
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(change.date, format: style)
                            Text(relative(change.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.shift > 0 ? LocalizedStringKey("Clocks Go Forward") : LocalizedStringKey("Clocks Go Back"))
                            Text(Duration.seconds(abs(change.shift)).formatted(.units(allowed: [.hours, .minutes], width: .wide)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func relative(_ date: Date) -> String {
        CountdownText.relativeDays(Countdown(startDate: date, isAllDay: false, recurrence: .never, now: now, calendar: .autoupdatingCurrent))
    }

    static func name(_ season: Astronomy.Season) -> LocalizedStringKey {
        switch season {
        case .marchEquinox: "March Equinox"
        case .juneSolstice: "June Solstice"
        case .septemberEquinox: "September Equinox"
        case .decemberSolstice: "December Solstice"
        }
    }

    /// Which season it starts where the user is: spring in March up north, autumn down south.
    private func beginning(_ season: Astronomy.Season) -> LocalizedStringKey {
        let north = place.latitude >= 0
        switch season {
        case .marchEquinox: return north ? "Spring begins" : "Autumn begins"
        case .juneSolstice: return north ? "Summer begins" : "Winter begins"
        case .septemberEquinox: return north ? "Autumn begins" : "Spring begins"
        case .decemberSolstice: return north ? "Winter begins" : "Summer begins"
        }
    }
}
