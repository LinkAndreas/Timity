import Foundation

nonisolated extension Astronomy.MoonPhase {
    /// "Waxing Gibbous".
    var name: LocalizedStringResource {
        switch self {
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
}
