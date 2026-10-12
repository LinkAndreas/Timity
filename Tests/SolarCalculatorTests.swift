import Foundation
import Testing
@testable import Timity

@Suite("Sun times")
struct SolarCalculatorTests {
    /// Local hour and minute of `date` in `timeZone`.
    private func clock(_ date: Date?, _ timeZone: String) -> Int? {
        guard let date else { return nil }
        let calendar = Calendar.fixture(timeZone: timeZone)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return components.hour! * 60 + components.minute!
    }

    private func expectClose(_ minutes: Int?, _ hour: Int, _ minute: Int, tolerance: Int = 3) {
        guard let minutes else {
            Issue.record("Expected \(hour):\(minute), got nothing")
            return
        }
        #expect(abs(minutes - (hour * 60 + minute)) <= tolerance, "Got \(minutes / 60):\(minutes % 60), expected \(hour):\(minute)")
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, _ latitude: Double, _ longitude: Double, _ timeZone: String) -> SolarDay {
        let calendar = Calendar.fixture(timeZone: timeZone)
        return SolarCalculator.day(
            containing: calendar.date(year, month, day, 12, 0),
            latitude: latitude,
            longitude: longitude,
            timeZone: TimeZone(identifier: timeZone)!
        )
    }

    @Test("Berlin at midsummer")
    func berlinSummer() {
        let sun = day(2024, 6, 21, 52.52, 13.405, "Europe/Berlin")
        #expect(sun.kind == .normal)
        expectClose(clock(sun.sunrise, "Europe/Berlin"), 4, 43)
        expectClose(clock(sun.sunset, "Europe/Berlin"), 21, 33)
        expectClose(clock(sun.solarNoon, "Europe/Berlin"), 13, 8)
    }

    @Test("Tokyo on New Year's Day, east of Greenwich")
    func tokyoWinter() {
        let sun = day(2024, 1, 1, 35.6762, 139.6503, "Asia/Tokyo")
        expectClose(clock(sun.sunrise, "Asia/Tokyo"), 6, 51)
        expectClose(clock(sun.sunset, "Asia/Tokyo"), 16, 38)
    }

    @Test("San Francisco, west of Greenwich")
    func sanFrancisco() {
        let sun = day(2024, 3, 20, 37.7749, -122.4194, "America/Los_Angeles")
        expectClose(clock(sun.sunrise, "America/Los_Angeles"), 7, 13)
        expectClose(clock(sun.sunset, "America/Los_Angeles"), 19, 22)
    }

    @Test("Sydney in the southern summer")
    func sydneySummer() {
        let sun = day(2024, 12, 21, -33.8688, 151.2093, "Australia/Sydney")
        expectClose(clock(sun.sunrise, "Australia/Sydney"), 5, 41)
        expectClose(clock(sun.sunset, "Australia/Sydney"), 20, 5)
    }

    @Test("Twilight comes in order")
    func twilightOrder() throws {
        let sun = day(2024, 9, 1, 48.137, 11.575, "Europe/Berlin")
        let morning = [sun.astronomicalDawn, sun.nauticalDawn, sun.civilDawn, sun.blueHourMorningEnd, sun.sunrise, sun.goldenHourMorningEnd]
        let evening = [sun.goldenHourEveningStart, sun.sunset, sun.blueHourEveningStart, sun.civilDusk, sun.nauticalDusk, sun.astronomicalDusk]
        let times = try (morning + [sun.solarNoon] + evening).map { try #require($0) }
        #expect(times == times.sorted())
    }

    @Test("Midnight sun and polar night in Tromsø")
    func polar() {
        let summer = day(2024, 6, 21, 69.6492, 18.9553, "Europe/Oslo")
        #expect(summer.kind == .polarDay)
        #expect(summer.sunrise == nil)
        #expect(summer.daylight == 24 * 3600)

        let winter = day(2024, 12, 21, 69.6492, 18.9553, "Europe/Oslo")
        #expect(winter.kind == .polarNight)
        #expect(winter.daylight == 0)
        // Civil twilight still happens around noon.
        #expect(winter.civilDawn != nil)
    }

    @Test("Times fall on the asked day beside the date line")
    func dateLine() {
        let timeZone = "Pacific/Tongatapu" // UTC+13
        let sun = day(2024, 6, 21, -21.1394, -175.2018, timeZone)
        let calendar = Calendar.fixture(timeZone: timeZone)
        for time in [sun.sunrise, sun.solarNoon, sun.sunset].compactMap({ $0 }) {
            #expect(calendar.component(.day, from: time) == 21)
        }
        #expect(sun.sunrise! < sun.solarNoon && sun.solarNoon < sun.sunset!)
    }

    @Test("The sun is high at noon and below the horizon at midnight")
    func elevation() {
        let calendar = Calendar.fixture(timeZone: "Europe/Berlin")
        let noon = SolarCalculator.elevation(at: calendar.date(2024, 6, 21, 13, 8), latitude: 52.52, longitude: 13.405)
        #expect(abs(noon - 60.9) < 0.5)
        let midnight = SolarCalculator.elevation(at: calendar.date(2024, 6, 21, 1, 8), latitude: 52.52, longitude: 13.405)
        #expect(midnight < 0)
    }
}
