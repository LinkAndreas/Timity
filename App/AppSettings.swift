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

    /// How the events list is sorted and filtered.
    struct EventListOptions: Equatable {
        var sort = EventSort.date
        /// Whether past one-off events are listed.
        var showsPastEvents = true
        var showsArchivedEvents = false
        /// The list the events are filtered to; `nil` for all.
        var selectedList: String?
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
    /// The app icon on the Home Screen — the thank-you for recurring support.
    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    /// The app's tint, free to choose for everyone.
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

    var eventList: EventListOptions {
        didSet {
            defaults.set(eventList.sort.rawValue, forKey: Key.eventSort)
            defaults.set(eventList.showsPastEvents, forKey: Key.showsPastEvents)
            defaults.set(eventList.showsArchivedEvents, forKey: Key.showsArchivedEvents)
            defaults.set(eventList.selectedList, forKey: Key.selectedList)
        }
    }

    /// Whether the welcome has been shown or skipped.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
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
        didSet { shared.birthday = birthday }
    }

    var lifeExpectancy: Int {
        didSet { shared.lifeExpectancy = lifeExpectancy }
    }

    @ObservationIgnored private let defaults: KeyValueStore
    @ObservationIgnored private let shared: SharedSettings

    /// - Parameters:
    ///   - defaults: The app's own preferences.
    ///   - shared: The preferences the widgets read too.
    init(defaults: KeyValueStore, shared: SharedSettings) {
        self.defaults = defaults
        self.shared = shared
        appearance = defaults.string(forKey: Key.appearance).flatMap { Appearance(rawValue: $0) }
            ?? Self.legacyAppearance(defaults.string(forKey: "themeType"))
        let theme = defaults.string(forKey: Key.theme).flatMap { AppTheme(rawValue: $0) } ?? .classic
        self.theme = theme
        // Without a tint of its own, the icon's colour, which used to set it, carries over.
        accentColor = defaults.string(forKey: Key.accentColor).flatMap { EventColor(rawValue: $0) } ?? theme.accentColor
        showsWeeks = defaults.object(forKey: Key.showsWeeks) as? Bool ?? true
        showsSeconds = defaults.object(forKey: Key.showsSeconds) as? Bool ?? true
        eventList = EventListOptions(
            sort: defaults.string(forKey: Key.eventSort).flatMap { EventSort(rawValue: $0) } ?? .date,
            showsPastEvents: defaults.object(forKey: Key.showsPastEvents) as? Bool ?? true,
            showsArchivedEvents: defaults.bool(forKey: Key.showsArchivedEvents),
            selectedList: defaults.string(forKey: Key.selectedList)
        )
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        milestoneAlerts = defaults.bool(forKey: Key.milestoneAlerts)
        switch defaults.string(forKey: Key.holidayRegion) {
        case "none": holidayRegion = nil
        case let code?: holidayRegion = HolidayRegion(rawValue: code)
        case nil: holidayRegion = HolidayRegion(locale: .autoupdatingCurrent)
        }
        birthday = shared.birthday
        lifeExpectancy = shared.lifeExpectancy
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
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appearance = "appearance"
        static let theme = "theme"
        static let accentColor = "tintColor"
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
