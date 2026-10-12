import Foundation

/// A place sunrise and sunset are worked out for.
struct Place: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var name: String?

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
    }
}

/// Settings the widgets and the Watch need too, kept in the app group's store.
/// Sendable because the store behind it, user defaults, is safe from any thread.
final class SharedSettings: @unchecked Sendable {
    private let store: KeyValueStore

    init(store: KeyValueStore) {
        self.store = store
    }

    private enum Key {
        static let birthday = "birthday"
        static let lifeExpectancy = "lifeExpectancy"
        static let pendingNewEvent = "pendingNewEvent"
        static let place = "sunPlace"
    }

    /// The last location the Sun tab or the Watch found.
    var place: Place? {
        get { store.data(forKey: Key.place).flatMap { try? JSONDecoder().decode(Place.self, from: $0) } }
        set { store.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.place) }
    }

    /// The user's own birthday, for Life in Weeks.
    var birthday: Date? {
        get { store.object(forKey: Key.birthday) as? Date }
        set { store.set(newValue, forKey: Key.birthday) }
    }

    /// The years Life in Weeks draws.
    var lifeExpectancy: Int {
        get { store.object(forKey: Key.lifeExpectancy) as? Int ?? 90 }
        set { store.set(newValue, forKey: Key.lifeExpectancy) }
    }

    /// Set by the Control Center control; the app opens a new event when it next becomes active.
    var hasPendingNewEvent: Bool {
        get { store.bool(forKey: Key.pendingNewEvent) }
        set { store.set(newValue, forKey: Key.pendingNewEvent) }
    }
}
