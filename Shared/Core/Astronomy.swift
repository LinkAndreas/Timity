import Foundation

/// The Moon and the seasons, after Jean Meeus' *Astronomical Algorithms*, with
/// the largest terms only: phases to within a few minutes, rise and set to within
/// a few minutes, equinoxes and solstices to within about a quarter of an hour.
enum Astronomy {
    // MARK: Moon phase

    enum MoonPhase: Int, CaseIterable, Sendable {
        case newMoon, waxingCrescent, firstQuarter, waxingGibbous, fullMoon, waningGibbous, lastQuarter, waningCrescent

        /// The phase for an elongation (Moon minus Sun longitude) in degrees.
        init(elongation: Double) {
            let index = Int(((Astronomy.normalized(elongation) + 22.5) / 45).rounded(.down)) % 8
            self = MoonPhase(rawValue: index) ?? .newMoon
        }

        var symbolName: String {
            switch self {
            case .newMoon: "moonphase.new.moon"
            case .waxingCrescent: "moonphase.waxing.crescent"
            case .firstQuarter: "moonphase.first.quarter"
            case .waxingGibbous: "moonphase.waxing.gibbous"
            case .fullMoon: "moonphase.full.moon"
            case .waningGibbous: "moonphase.waning.gibbous"
            case .lastQuarter: "moonphase.last.quarter"
            case .waningCrescent: "moonphase.waning.crescent"
            }
        }
    }

    /// The four principal phases, by the Moon's elongation from the Sun.
    enum PrincipalPhase: Double, CaseIterable, Sendable {
        case newMoon = 0
        case firstQuarter = 90
        case fullMoon = 180
        case lastQuarter = 270
    }

    struct MoonState: Equatable, Sendable {
        let phase: MoonPhase
        /// The lit fraction of the disc, from 0 to 1.
        let illumination: Double
        /// Days since the last new moon.
        let age: Double
    }

    static func moon(at date: Date) -> MoonState {
        let elongation = self.elongation(at: date)
        let illumination = (1 - cos(radians(elongation))) / 2
        return MoonState(
            phase: MoonPhase(elongation: elongation),
            illumination: illumination,
            age: normalized(elongation) / 360 * synodicMonth
        )
    }

    /// The next time after `date` the Moon reaches `phase`.
    static func next(_ phase: PrincipalPhase, after date: Date) -> Date {
        let degreesPerDay = 360 / synodicMonth
        var ahead = normalized(phase.rawValue - elongation(at: date))
        if ahead < 0.5 { ahead += 360 }
        var time = date.addingTimeInterval(ahead / degreesPerDay * 86_400)
        // Newton steps on the elongation, which grows by about 12° a day.
        for _ in 0..<6 {
            let difference = signed(elongation(at: time) - phase.rawValue)
            time.addTimeInterval(-difference / degreesPerDay * 86_400)
        }
        return time
    }

    // MARK: Moonrise and moonset

    struct MoonTimes: Equatable, Sendable {
        let rise: Date?
        let set: Date?
    }

    /// When the Moon rises and sets on the day that `dayStart` begins, in the place's time.
    static func moonTimes(dayStart: Date, dayEnd: Date, latitude: Double, longitude: Double) -> MoonTimes {
        // The altitude at which the Moon's upper edge touches the horizon, with refraction and parallax.
        func offsetAltitude(_ date: Date) -> Double {
            let position = moonPosition(at: date)
            let parallax = degrees(asin(6378.14 / position.distance))
            let horizon = 0.7275 * parallax - 0.5667
            return altitude(of: position, at: date, latitude: latitude, longitude: longitude) - horizon
        }

        var rise: Date?
        var set: Date?
        let step: TimeInterval = 600
        var previousTime = dayStart
        var previousValue = offsetAltitude(dayStart)
        var time = dayStart
        while time < dayEnd, rise == nil || set == nil {
            time = min(time.addingTimeInterval(step), dayEnd)
            let value = offsetAltitude(time)
            if previousValue.sign != value.sign {
                // Interpolate within the ten minutes.
                let fraction = previousValue / (previousValue - value)
                let crossing = previousTime.addingTimeInterval(fraction * time.timeIntervalSince(previousTime))
                if value > 0, rise == nil { rise = crossing }
                if value < 0, set == nil { set = crossing }
            }
            previousTime = time
            previousValue = value
        }
        return MoonTimes(rise: rise, set: set)
    }

    // MARK: Seasons

    enum Season: Double, CaseIterable, Sendable {
        case marchEquinox = 0
        case juneSolstice = 90
        case septemberEquinox = 180
        case decemberSolstice = 270
    }

    /// The next equinox or solstice after `date`, and which one it is.
    static func nextSeason(after date: Date) -> (season: Season, date: Date) {
        Season.allCases
            .map { ($0, next($0, after: date)) }
            .min { $0.1 < $1.1 }!
    }

    /// The next time after `date` the Sun reaches the season's longitude.
    static func next(_ season: Season, after date: Date) -> Date {
        let degreesPerDay = 360 / 365.2422
        var ahead = normalized(season.rawValue - sunLongitude(at: date))
        if ahead < 0.01 { ahead += 360 }
        var time = date.addingTimeInterval(ahead / degreesPerDay * 86_400)
        for _ in 0..<5 {
            let difference = signed(sunLongitude(at: time) - season.rawValue)
            time.addTimeInterval(-difference / degreesPerDay * 86_400)
        }
        return time
    }

    // MARK: Clock changes

    struct ClockChange: Equatable, Sendable {
        let date: Date
        /// Positive when the clocks go forward.
        let shift: TimeInterval
    }

    /// The next daylight saving change in `timeZone`, if it has one.
    static func nextClockChange(after date: Date, in timeZone: TimeZone) -> ClockChange? {
        guard let transition = timeZone.nextDaylightSavingTimeTransition(after: date) else { return nil }
        let before = timeZone.secondsFromGMT(for: transition.addingTimeInterval(-1))
        let after = timeZone.secondsFromGMT(for: transition.addingTimeInterval(1))
        return ClockChange(date: transition, shift: TimeInterval(after - before))
    }

    // MARK: Private

    private static let synodicMonth = 29.530588853

    private struct MoonPosition {
        let longitude: Double
        let latitude: Double
        /// In kilometres.
        let distance: Double
    }

    /// Julian centuries since J2000.0.
    private static func centuries(_ date: Date) -> Double {
        (julianDay(date) - 2_451_545.0) / 36_525
    }

    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func elongation(at date: Date) -> Double {
        normalized(moonPosition(at: date).longitude - sunLongitude(at: date))
    }

    /// The Sun's apparent ecliptic longitude in degrees.
    private static func sunLongitude(at date: Date) -> Double {
        let t = centuries(date)
        let l0 = 280.46646 + 36_000.76983 * t + 0.0003032 * t * t
        let m = radians(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)
        let center = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m)
            + (0.019993 - 0.000101 * t) * sin(2 * m)
            + 0.000289 * sin(3 * m)
        let omega = radians(125.04 - 1_934.136 * t)
        return normalized(l0 + center - 0.00569 - 0.00478 * sin(omega))
    }

    private static func moonPosition(at date: Date) -> MoonPosition {
        let t = centuries(date)
        let lp = 218.3164477 + 481_267.88123421 * t
        let d = radians(297.8501921 + 445_267.1114034 * t)
        let m = radians(357.5291092 + 35_999.0502909 * t)
        let mp = radians(134.9633964 + 477_198.8675055 * t)
        let f = radians(93.2720950 + 483_202.0175233 * t)
        let e = 1 - 0.002516 * t

        let longitude = lp
            + 6.288774 * sin(mp)
            + 1.274027 * sin(2 * d - mp)
            + 0.658314 * sin(2 * d)
            + 0.213618 * sin(2 * mp)
            - 0.185116 * e * sin(m)
            - 0.114332 * sin(2 * f)
            + 0.058793 * sin(2 * d - 2 * mp)
            + 0.057066 * e * sin(2 * d - m - mp)
            + 0.053322 * sin(2 * d + mp)
            + 0.045758 * e * sin(2 * d - m)
            - 0.040923 * e * sin(m - mp)
            - 0.034720 * sin(d)
            - 0.030383 * e * sin(m + mp)
            + 0.015327 * sin(2 * d - 2 * f)
            - 0.012528 * sin(mp + 2 * f)
            + 0.010980 * sin(mp - 2 * f)
            + 0.010675 * sin(4 * d - mp)
            + 0.010034 * sin(3 * mp)
            + 0.008548 * sin(4 * d - 2 * mp)
            - 0.007888 * e * sin(2 * d + m - mp)
            - 0.006766 * e * sin(2 * d + m)
            - 0.005163 * sin(d - mp)
            + 0.004987 * e * sin(d + m)
            + 0.004036 * e * sin(2 * d - m + mp)

        let latitude = 5.128122 * sin(f)
            + 0.280602 * sin(mp + f)
            + 0.277693 * sin(mp - f)
            + 0.173237 * sin(2 * d - f)
            + 0.055413 * sin(2 * d - mp + f)
            + 0.046271 * sin(2 * d - mp - f)
            + 0.032573 * sin(2 * d + f)
            + 0.017198 * sin(2 * mp + f)

        let distance = 385_000.56
            - 20_905.355 * cos(mp)
            - 3_699.111 * cos(2 * d - mp)
            - 2_955.968 * cos(2 * d)
            - 569.925 * cos(2 * mp)
            + 48.888 * e * cos(m)
            - 3.149 * cos(2 * f)
            + 246.158 * cos(2 * d - 2 * mp)
            - 152.138 * e * cos(2 * d - m - mp)
            - 170.733 * cos(2 * d + mp)
            - 204.586 * e * cos(2 * d - m)
            - 129.620 * e * cos(m - mp)
            + 108.743 * cos(d)
            + 104.755 * e * cos(m + mp)

        return MoonPosition(longitude: normalized(longitude), latitude: latitude, distance: distance)
    }

    /// The geocentric altitude in degrees of a body at ecliptic coordinates.
    private static func altitude(of position: MoonPosition, at date: Date, latitude: Double, longitude: Double) -> Double {
        let t = centuries(date)
        let obliquity = radians(23.439291 - 0.0130042 * t)
        let lambda = radians(position.longitude)
        let beta = radians(position.latitude)
        let rightAscension = atan2(sin(lambda) * cos(obliquity) - tan(beta) * sin(obliquity), cos(lambda))
        let declination = asin(sin(beta) * cos(obliquity) + cos(beta) * sin(obliquity) * sin(lambda))

        let jd = julianDay(date)
        let siderealTime = normalized(280.46061837 + 360.98564736629 * (jd - 2_451_545.0) + 0.000387933 * t * t)
        let hourAngle = radians(siderealTime + longitude) - rightAscension
        let phi = radians(latitude)
        let sinAltitude = sin(phi) * sin(declination) + cos(phi) * cos(declination) * cos(hourAngle)
        return degrees(asin(min(max(sinAltitude, -1), 1)))
    }

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// An angle difference between -180° and 180°.
    private static func signed(_ degrees: Double) -> Double {
        let value = normalized(degrees)
        return value > 180 ? value - 360 : value
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
