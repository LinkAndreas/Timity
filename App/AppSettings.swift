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
            case .system: "app.system"
            case .light: "app.light"
            case .dark: "app.dark"
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
            case .date: "common.date"
            case .title: "common.name"
            case .created: "app.dateAdded"
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    /// The app icon on the Home Screen — the thank-you for recurring support.
    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    /// The app's tint, free to choose for everyone.
    var accentColor: EventColor {
        didSet { defaults.set(accentColor.rawValue, forKey: Key.accentColor) }
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

    /// The What's New the user last saw; `nil` before the first.
    var lastSeenWhatsNew: String? {
        didSet { defaults.set(lastSeenWhatsNew, forKey: Key.lastSeenWhatsNew) }
    }

    /// Whether Timity sends a notification on milestones such as 10,000 days.
    var milestoneAlerts: Bool {
        didSet { defaults.set(milestoneAlerts, forKey: Key.milestoneAlerts) }
    }

    /// Whether crash and hang reports go to the developer; off unless the user turns it on.
    var sharesDiagnostics: Bool {
        didSet { defaults.set(sharesDiagnostics, forKey: Self.sharesDiagnosticsKey) }
    }

    /// Read off the main thread too, when a report arrives.
    nonisolated static let sharesDiagnosticsKey = "sharesDiagnostics"

    /// Whether events sync through iCloud.
    var syncsWithICloud: Bool {
        didSet { defaults.set(syncsWithICloud, forKey: Key.syncsWithICloud) }
    }

    /// Whether events sync now: only once the welcome, which asks, is done.
    var syncsAfterOnboarding: Bool {
        syncsWithICloud && hasCompletedOnboarding
    }

    /// Whose public holidays working days leave out; `nil` for none.
    var holidayRegion: HolidayRegion? {
        didSet { defaults.set(holidayRegion?.rawValue ?? "none", forKey: Key.holidayRegion) }
    }

    /// The user's birthday, for Life in Weeks.
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
        // Without a tint of its own, the colour Timity 3 highlighted everything in, else the
        // icon's colour, which used to set it, carries over.
        accentColor = defaults.string(forKey: Key.accentColor).flatMap { EventColor(rawValue: $0) }
            ?? LegacyImporter.highlightColor(in: defaults)
            ?? theme.accentColor
        eventList = EventListOptions(
            sort: defaults.string(forKey: Key.eventSort).flatMap { EventSort(rawValue: $0) }
                ?? Self.legacySort(defaults.string(forKey: "sortBy"))
                ?? .date,
            showsPastEvents: defaults.object(forKey: Key.showsPastEvents) as? Bool ?? true,
            showsArchivedEvents: defaults.bool(forKey: Key.showsArchivedEvents),
            selectedList: defaults.string(forKey: Key.selectedList)
        )
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        milestoneAlerts = defaults.bool(forKey: Key.milestoneAlerts)
        sharesDiagnostics = defaults.bool(forKey: Self.sharesDiagnosticsKey)
        lastSeenWhatsNew = defaults.string(forKey: Key.lastSeenWhatsNew)
        syncsWithICloud = defaults.object(forKey: Key.syncsWithICloud) as? Bool ?? true
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

    /// The order Timity 3 listed events in; `nil` when never changed there.
    private static func legacySort(_ sortBy: String?) -> EventSort? {
        switch sortBy {
        case "nameOfEvent": .title
        case "dateOfEvent": .date
        case "dateOfCreation": .created
        default: nil
        }
    }


    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appearance = "appearance"
        static let theme = "theme"
        static let accentColor = "tintColor"
        static let eventSort = "eventSort"
        static let showsPastEvents = "showsPastEvents"
        static let showsArchivedEvents = "showsArchivedEvents"
        static let selectedList = "selectedList"
        static let milestoneAlerts = "milestoneAlerts"
        static let lastSeenWhatsNew = "lastSeenWhatsNew"
        static let syncsWithICloud = "syncsWithICloud"
        static let holidayRegion = "holidayRegion"
    }
}
