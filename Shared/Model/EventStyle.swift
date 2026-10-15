import Foundation

/// The colour of an event's badge, card and widget: plain colours, then gradients.
nonisolated enum EventColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, graphite
    case sunrise, aurora, lagoon, blossom, ember, nightfall

    var id: String { rawValue }
}

/// The SF Symbols offered for events, grouped for the picker.
nonisolated enum EventSymbol {
    static let defaultName = "star.fill"

    static let groups: [(title: LocalizedStringResource, symbols: [String])] = [
        ("shared.celebrations", [
            "star.fill", "birthday.cake.fill", "gift.fill", "party.popper.fill", "balloon.2.fill",
            "heart.fill", "sparkles", "crown.fill", "trophy.fill", "graduationcap.fill",
        ]),
        ("shared.travelOutdoors", [
            "airplane", "suitcase.rolling.fill", "car.fill", "tram.fill", "sailboat.fill",
            "beach.umbrella.fill", "mountain.2.fill", "tent.fill", "globe.europe.africa.fill", "map.fill",
        ]),
        ("shared.life", [
            "house.fill", "figure.and.child.holdinghands", "stroller.fill", "pawprint.fill", "leaf.fill",
            "cross.case.fill", "heart.text.clipboard.fill", "dumbbell.fill", "figure.run", "bicycle",
        ]),
        ("shared.workStudy", [
            "briefcase.fill", "book.fill", "pencil.and.ruler.fill", "laptopcomputer", "chart.line.uptrend.xyaxis",
            "calendar", "clock.fill", "hourglass", "flag.checkered", "checkmark.seal.fill",
        ]),
        ("shared.fun", [
            "music.note", "film.fill", "gamecontroller.fill", "theatermasks.fill", "sportscourt.fill",
            "soccerball", "fork.knife", "wineglass.fill", "cup.and.saucer.fill", "camera.fill",
        ]),
        ("common.seasons", [
            "sun.max.fill", "moon.stars.fill", "snowflake", "tree.fill", "flame.fill",
            "cloud.sun.fill", "umbrella.fill", "drop.fill", "bolt.fill", "rainbow",
        ]),
    ]
}
