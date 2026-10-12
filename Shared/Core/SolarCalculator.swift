import Foundation

/// The sun's times for one day at one place.
struct SolarDay: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case normal
        /// The sun doesn't set (midnight sun).
        case polarDay
        /// The sun doesn't rise.
        case polarNight
    }

    let kind: Kind
    let solarNoon: Date
    let sunrise: Date?
    let sunset: Date?
    let civilDawn: Date?
    let civilDusk: Date?
    let nauticalDawn: Date?
    let nauticalDusk: Date?
    let astronomicalDawn: Date?
    let astronomicalDusk: Date?
    /// The morning golden hour ends when the sun is 6° above the horizon.
    let goldenHourMorningEnd: Date?
    /// The evening golden hour starts when the sun sinks to 6° above the horizon.
    let goldenHourEveningStart: Date?
    /// The morning blue hour ends when the sun is 4° below the horizon.
    let blueHourMorningEnd: Date?
    /// The evening blue hour starts when the sun is 4° below the horizon.
    let blueHourEveningStart: Date?

    /// Time between sunrise and sunset; a full day of daylight in polar summer.
    var daylight: TimeInterval {
        switch kind {
        case .polarDay: 24 * 3600
        case .polarNight: 0
        case .normal:
            if let sunrise, let sunset { sunset.timeIntervalSince(sunrise) } else { 0 }
        }
    }
}

/// Sun positions after the NOAA solar calculator, accurate to about a minute
/// between the polar circles.
enum SolarCalculator {
    /// Angles below the zenith that define each sun event, in degrees.
    private enum Zenith {
        /// The upper edge of the sun on the horizon, including refraction.
        static let official = 90.833
        static let civil = 96.0
        static let nautical = 102.0
        static let astronomical = 108.0
        static let goldenHour = 84.0
        static let blueHour = 94.0
    }

    /// The sun's times on the day `date` falls on in `timeZone`. The times are
    /// absolute moments; show them in `timeZone` to get the place's local times.
    static func day(
        containing date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        let noon = solarNoon(dayStart: dayStart, dayEnd: dayEnd, longitude: longitude, calendar: calendar)
        func time(_ zenith: Double, rising: Bool) -> Date? {
            eventTime(zenith: zenith, rising: rising, noon: noon, latitude: latitude)
        }

        let sunrise = time(Zenith.official, rising: true)
        let sunset = time(Zenith.official, rising: false)
        let kind: SolarDay.Kind
        if sunrise != nil || sunset != nil {
            kind = .normal
        } else {
            kind = elevation(at: noon, latitude: latitude, longitude: longitude) > 0 ? .polarDay : .polarNight
        }

        return SolarDay(
            kind: kind,
            solarNoon: noon,
            sunrise: sunrise,
            sunset: sunset,
            civilDawn: time(Zenith.civil, rising: true),
            civilDusk: time(Zenith.civil, rising: false),
            nauticalDawn: time(Zenith.nautical, rising: true),
            nauticalDusk: time(Zenith.nautical, rising: false),
            astronomicalDawn: time(Zenith.astronomical, rising: true),
            astronomicalDusk: time(Zenith.astronomical, rising: false),
            goldenHourMorningEnd: time(Zenith.goldenHour, rising: true),
            goldenHourEveningStart: time(Zenith.goldenHour, rising: false),
            blueHourMorningEnd: time(Zenith.blueHour, rising: true),
            blueHourEveningStart: time(Zenith.blueHour, rising: false)
        )
    }

    /// The sun's height above the horizon at `date`, in degrees; negative at night.
    /// Doesn't include atmospheric refraction.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let (equationOfTime, declination) = parameters(at: date)
        let minutesSinceMidnightUTC = date.timeIntervalSince(utcMidnight(of: date)) / 60
        let trueSolarTime = minutesSinceMidnightUTC + equationOfTime + 4 * longitude
        let hourAngle = radians(trueSolarTime / 4 - 180)
        let lat = radians(latitude)
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return 90 - degrees(acos(min(max(cosZenith, -1), 1)))
    }

    // MARK: Private

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// The moment the sun is highest, within the local day.
    private static func solarNoon(dayStart: Date, dayEnd: Date, longitude: Double, calendar: Calendar) -> Date {
        // Midday of the local date, read as UTC, is close to the answer; the
        // equation of time and longitude give the exact moment.
        let components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let utcMidnight = utcCalendar.date(from: components) ?? dayStart
        let estimate = utcMidnight.addingTimeInterval((720 - 4 * longitude) * 60)
        let (equationOfTime, _) = parameters(at: estimate)
        var noon = utcMidnight.addingTimeInterval((720 - 4 * longitude - equationOfTime) * 60)

        // Near the date line the local day and the UTC day differ by one.
        while noon < dayStart { noon.addTimeInterval(86_400) }
        while noon >= dayEnd { noon.addTimeInterval(-86_400) }
        return noon
    }

    /// When the sun crosses `zenith` before (`rising`) or after solar noon, or `nil`
    /// if it doesn't that day.
    private static func eventTime(zenith: Double, rising: Bool, noon: Date, latitude: Double) -> Date? {
        let lat = radians(latitude)
        var time = noon
        // The declination changes slowly; recomputing it at the estimate converges quickly.
        for _ in 0..<3 {
            let (_, declination) = parameters(at: time)
            let cosHourAngle = cos(radians(zenith)) / (cos(lat) * cos(declination)) - tan(lat) * tan(declination)
            guard (-1...1).contains(cosHourAngle) else { return nil }
            let hourAngleMinutes = 4 * degrees(acos(cosHourAngle))
            time = noon.addingTimeInterval((rising ? -hourAngleMinutes : hourAngleMinutes) * 60)
        }
        return time
    }

    /// The equation of time in minutes and the sun's declination in radians at `date`.
    private static func parameters(at date: Date) -> (equationOfTime: Double, declination: Double) {
        let dayOfYear = Double(utcCalendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let daysInYear = Double(utcCalendar.range(of: .day, in: .year, for: date)?.count ?? 365)
        let hour = date.timeIntervalSince(utcMidnight(of: date)) / 3600
        let gamma = 2 * Double.pi / daysInYear * (dayOfYear - 1 + (hour - 12) / 24)

        let equationOfTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let declination = 0.006918
            - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        return (equationOfTime, declination)
    }

    private static func utcMidnight(of date: Date) -> Date {
        utcCalendar.startOfDay(for: date)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
