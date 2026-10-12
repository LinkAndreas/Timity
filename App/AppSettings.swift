import Observation
import SwiftUI

/// The user's preferences, kept in user defaults.
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }

        var name: LocalizedStringResource {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    enum EventSort: String, CaseIterable, Identifiable {
        case date, title, created

        var id: String { rawValue }

        var name: LocalizedStringResource {
            switch self {
            case .date: "Date"
            case .title: "Name"
            case .created: "Date Added"
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var accentColor: EventColor {
        didSet { defaults.set(accentColor.rawValue, forKey: Key.accentColor) }
    }

    /// Whether breakdowns take whole weeks out of the days.
    var showsWeeks: Bool {
        didSet { defaults.set(showsWeeks, forKey: Key.showsWeeks) }
    }

    /// Whether countdowns tick by the second.
    var showsSeconds: Bool {
        didSet { defaults.set(showsSeconds, forKey: Key.showsSeconds) }
    }

    var eventSort: EventSort {
        didSet { defaults.set(eventSort.rawValue, forKey: Key.eventSort) }
    }

    /// Whether past one-off events are listed.
    var showsPastEvents: Bool {
        didSet { defaults.set(showsPastEvents, forKey: Key.showsPastEvents) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance).flatMap { Appearance(rawValue: $0) }
            ?? Self.legacyAppearance(defaults.string(forKey: "themeType"))
        accentColor = defaults.string(forKey: Key.accentColor).flatMap { EventColor(rawValue: $0) }
            ?? Self.legacyAccentColor(defaults.string(forKey: "highlightColor"))
        showsWeeks = defaults.object(forKey: Key.showsWeeks) as? Bool ?? true
        showsSeconds = defaults.object(forKey: Key.showsSeconds) as? Bool ?? true
        eventSort = defaults.string(forKey: Key.eventSort).flatMap { EventSort(rawValue: $0) } ?? .date
        showsPastEvents = defaults.object(forKey: Key.showsPastEvents) as? Bool ?? true
    }

    /// The theme chosen in Timity 3, which had a black theme of its own.
    private static func legacyAppearance(_ themeType: String?) -> Appearance {
        switch themeType {
        case "light": .light
        case "dark", "black": .dark
        default: .system
        }
    }

    /// The highlight colour chosen in Timity 3.
    private static func legacyAccentColor(_ highlightColor: String?) -> EventColor {
        switch highlightColor {
        case "teal blue": .teal
        case let name?: EventColor(rawValue: name) ?? .orange
        case nil: .orange
        }
    }

    private enum Key {
        static let appearance = "appearance"
        static let accentColor = "accentColor"
        static let showsWeeks = "showsWeeks"
        static let showsSeconds = "showsSeconds"
        static let eventSort = "eventSort"
        static let showsPastEvents = "showsPastEvents"
    }
}
