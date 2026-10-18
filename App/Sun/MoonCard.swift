import SwiftUI

/// When the Moon rises and sets on the chosen day at the place, if there is one,
/// and when the next phases come.
struct MoonTimesCard: View {
    let place: Place?
    let date: Date
    let now: Date
    let time: Date.FormatStyle

    var body: some View {
        let timeZone = place?.timeZone ?? .autoupdatingCurrent
        let moment = MoonMoment.of(date, now: now, timeZone: timeZone)
        let phases = Astronomy.PrincipalPhase.allCases
            .map { ($0, Astronomy.next($0, after: moment)) }
            .sorted { $0.1 < $1.1 }

        Card(title: "astronomy.riseSetAndPhases") {
            VStack(spacing: 10) {
                if let place {
                    let calendar = placeCalendar(place)
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
                    let times = Astronomy.moonTimes(dayStart: dayStart, dayEnd: dayEnd, latitude: place.latitude, longitude: place.longitude)
                    LabeledContent("astronomy.moonrise", value: times.rise?.formatted(time) ?? String(localized: "astronomy.noneToday"))
                    LabeledContent("astronomy.moonset", value: times.set?.formatted(time) ?? String(localized: "astronomy.noneToday"))
                    Divider()
                }
                ForEach(phases, id: \.0) { phase, when in
                    LabeledContent {
                        Text(verbatim: when.formatted(.shortDate(withTime: true, in: timeZone)))
                            .monospacedDigit()
                    } label: {
                        Label {
                            Text(Self.name(phase))
                        } icon: {
                            MoonPhaseView(phase, isSouthern: (place?.latitude ?? 0) < 0)
                                .frame(width: 16, height: 16)
                        }
                    }
                }
            }
        }
    }

    private func placeCalendar(_ place: Place) -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = place.timeZone
        return calendar
    }

    static func name(_ phase: Astronomy.MoonPhase) -> LocalizedStringKey {
        switch phase {
        case .newMoon: "astronomy.newMoon"
        case .waxingCrescent: "astronomy.waxingCrescent"
        case .firstQuarter: "astronomy.firstQuarter"
        case .waxingGibbous: "astronomy.waxingGibbous"
        case .fullMoon: "astronomy.fullMoon"
        case .waningGibbous: "astronomy.waningGibbous"
        case .lastQuarter: "astronomy.lastQuarter"
        case .waningCrescent: "astronomy.waningCrescent"
        }
    }

    static func name(_ phase: Astronomy.PrincipalPhase) -> LocalizedStringKey {
        switch phase {
        case .newMoon: "astronomy.newMoon"
        case .firstQuarter: "astronomy.firstQuarter"
        case .fullMoon: "astronomy.fullMoon"
        case .lastQuarter: "astronomy.lastQuarter"
        }
    }
}

/// The next equinox or solstice, and the next time the clocks change.
struct SeasonsCard: View {
    let place: Place
    let now: Date

    var body: some View {
        let next = Astronomy.nextSeason(after: now)
        let change = Astronomy.nextClockChange(after: now, in: place.timeZone)
        let style = Date.FormatStyle.shortDate(withTime: true, in: place.timeZone)

        Card(title: "common.seasons") {
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
                            Text(change.shift > 0 ? LocalizedStringKey("astronomy.clocksGoForward") : LocalizedStringKey("astronomy.clocksGoBack"))
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
        case .marchEquinox: "astronomy.marchEquinox"
        case .juneSolstice: "astronomy.juneSolstice"
        case .septemberEquinox: "astronomy.septemberEquinox"
        case .decemberSolstice: "astronomy.decemberSolstice"
        }
    }

    /// Which season it starts where the user is: spring in March up north, autumn down south.
    private func beginning(_ season: Astronomy.Season) -> LocalizedStringKey {
        let north = place.latitude >= 0
        switch season {
        case .marchEquinox: return north ? "astronomy.springBegins" : "astronomy.autumnBegins"
        case .juneSolstice: return north ? "astronomy.summerBegins" : "astronomy.winterBegins"
        case .septemberEquinox: return north ? "astronomy.autumnBegins" : "astronomy.springBegins"
        case .decemberSolstice: return north ? "astronomy.winterBegins" : "astronomy.summerBegins"
        }
    }
}
