import Foundation

/// The app icons, free for everyone to choose in Settings.
///
/// Each theme pairs an alternate icon (`App/AppIcons/AppIcon-<Name>.icon`) with the
/// app's tint. `classic` is the primary icon. The picker shows `IconPreview-<Name>`
/// images, since app icons can't be loaded as images.
nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case classic = "Classic"
    case sunrise = "Sunrise"
    case lagoon = "Lagoon"
    case forest = "Forest"
    case rose = "Rose"
    case midnight = "Midnight"
    case ember = "Ember"

    var id: String { rawValue }

    /// The alternate icon's name in the asset catalog; `nil` for the primary icon.
    var alternateIconName: String? {
        self == .classic ? nil : "AppIcon-\(rawValue)"
    }

    var previewImageName: String { "IconPreview-\(rawValue)" }

    /// The app's tint with this icon, matched to its sand.
    var accentColor: EventColor {
        switch self {
        case .classic: .orange
        case .sunrise: .sunrise
        case .lagoon: .lagoon
        case .forest: .green
        case .rose: .blossom
        case .midnight: .indigo
        case .ember: .ember
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .classic: "appIcon.classic"
        case .sunrise: "common.sunrise"
        case .lagoon: "common.lagoon"
        case .forest: "appIcon.forest"
        case .rose: "appIcon.rose"
        case .midnight: "appIcon.midnight"
        case .ember: "common.ember"
        }
    }

    /// The theme whose icon is `UIApplication.alternateIconName`.
    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .classic
    }
}
