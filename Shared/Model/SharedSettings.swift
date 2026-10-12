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
