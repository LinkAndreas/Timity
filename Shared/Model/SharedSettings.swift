import Foundation

/// Settings the widgets need too, kept in the app group's user defaults.
enum SharedSettings {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: TimityStore.appGroup) ?? .standard
    }

    private enum Key {
        static let birthday = "birthday"
        static let lifeExpectancy = "lifeExpectancy"
        static let pendingNewEvent = "pendingNewEvent"
        static let place = "sunPlace"
    }

    /// A place for the Sun widgets: the last location the app found.
    struct Place: Codable, Equatable, Sendable {
        var latitude: Double
        var longitude: Double
        var timeZoneIdentifier: String
        var name: String?

        var timeZone: TimeZone {
            TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
        }
    }

    /// The last location the Sun tab or the Watch found, for widgets and complications.
    static var place: Place? {
        get { defaults.data(forKey: Key.place).flatMap { try? JSONDecoder().decode(Place.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.place) }
    }

    /// The user's own birthday, for Life in Weeks.
    static var birthday: Date? {
        get { defaults.object(forKey: Key.birthday) as? Date }
        set { defaults.set(newValue, forKey: Key.birthday) }
    }

    /// The years Life in Weeks draws.
    static var lifeExpectancy: Int {
        get { (defaults.object(forKey: Key.lifeExpectancy) as? Int) ?? 90 }
        set { defaults.set(newValue, forKey: Key.lifeExpectancy) }
    }

    /// Set by the Control Center control; the app opens a new event when it next becomes active.
    static var hasPendingNewEvent: Bool {
        get { defaults.bool(forKey: Key.pendingNewEvent) }
        set { defaults.set(newValue, forKey: Key.pendingNewEvent) }
    }
}
