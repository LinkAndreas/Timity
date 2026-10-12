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

    /// The app icon and its matching tint.
    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    var accentColor: EventColor { theme.accentColor }

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

    var showsArchivedEvents: Bool {
        didSet { defaults.set(showsArchivedEvents, forKey: Key.showsArchivedEvents) }
    }

    /// The list the events are filtered to; `nil` for all.
    var selectedList: String? {
        didSet { defaults.set(selectedList, forKey: Key.selectedList) }
    }

    /// Whether Timity sends a notification on milestones such as 10,000 days.
    var milestoneAlerts: Bool {
        didSet { defaults.set(milestoneAlerts, forKey: Key.milestoneAlerts) }
    }

    /// Whose public holidays working days leave out; `nil` for none.
    var holidayRegion: HolidayRegion? {
        didSet { defaults.set(holidayRegion?.rawValue ?? "none", forKey: Key.holidayRegion) }
    }

    /// The user's birthday, for Life in Weeks; shared with the widgets.
    var birthday: Date? {
        didSet { SharedSettings.birthday = birthday }
    }

    var lifeExpectancy: Int {
        didSet { SharedSettings.lifeExpectancy = lifeExpectancy }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Key.appearance).flatMap { Appearance(rawValue: $0) }
            ?? Self.legacyAppearance(defaults.string(forKey: "themeType"))
        theme = defaults.string(forKey: Key.theme).flatMap { AppTheme(rawValue: $0) } ?? .classic
        showsWeeks = defaults.object(forKey: Key.showsWeeks) as? Bool ?? true
        showsSeconds = defaults.object(forKey: Key.showsSeconds) as? Bool ?? true
        eventSort = defaults.string(forKey: Key.eventSort).flatMap { EventSort(rawValue: $0) } ?? .date
        showsPastEvents = defaults.object(forKey: Key.showsPastEvents) as? Bool ?? true
        showsArchivedEvents = defaults.bool(forKey: Key.showsArchivedEvents)
        selectedList = defaults.string(forKey: Key.selectedList)
        milestoneAlerts = defaults.bool(forKey: Key.milestoneAlerts)
        switch defaults.string(forKey: Key.holidayRegion) {
        case "none": holidayRegion = nil
        case let code?: holidayRegion = HolidayRegion(rawValue: code)
        case nil: holidayRegion = HolidayRegion(locale: .autoupdatingCurrent)
        }
        birthday = SharedSettings.birthday
        lifeExpectancy = SharedSettings.lifeExpectancy
    }

    /// The theme chosen in Timity 3, which had a black theme of its own.
    private static func legacyAppearance(_ themeType: String?) -> Appearance {
        switch themeType {
        case "light": .light
        case "dark", "black": .dark
        default: .system
        }
    }


    private enum Key {
        static let appearance = "appearance"
        static let theme = "theme"
        static let showsWeeks = "showsWeeks"
        static let showsSeconds = "showsSeconds"
        static let eventSort = "eventSort"
        static let showsPastEvents = "showsPastEvents"
        static let showsArchivedEvents = "showsArchivedEvents"
        static let selectedList = "selectedList"
        static let milestoneAlerts = "milestoneAlerts"
        static let holidayRegion = "holidayRegion"
    }
}
