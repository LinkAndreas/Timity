import Foundation

/// Where small values such as preferences are kept. `UserDefaults` is one;
/// `InMemoryKeyValueStore` stands in for previews and tests.
nonisolated protocol KeyValueStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

nonisolated extension KeyValueStore {
    func bool(forKey key: String) -> Bool { object(forKey: key) as? Bool ?? false }
    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
}

nonisolated extension UserDefaults: KeyValueStore {}

nonisolated final class InMemoryKeyValueStore: KeyValueStore {
    private var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}
