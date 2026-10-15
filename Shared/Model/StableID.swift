import CryptoKit
import Foundation

nonisolated extension UUID {
    /// The same UUID for the same name on every device, in the manner of a
    /// name-based (version 5) UUID. Events made from the same source on two
    /// devices — a contact's birthday, a holiday, a welcome suggestion — then
    /// share their ID and count as one event once iCloud brings them together.
    init(stableFrom name: String) {
        var bytes = Array(SHA256.hash(data: Data(name.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

nonisolated extension Array where Element == EventSnapshot {
    /// One event per ID, the most recently changed, in the order they first appear.
    /// Two devices can store the same event before iCloud brings them together;
    /// both copies stay stored, as removing one on each device could remove both.
    var oneByID: [EventSnapshot] {
        var latest: [UUID: EventSnapshot] = [:]
        for event in self where latest[event.id].map({ event.modifiedAt > $0.modifiedAt }) ?? true {
            latest[event.id] = event
        }
        var seen = Set<UUID>()
        return compactMap { event in seen.insert(event.id).inserted ? latest[event.id] : nil }
    }
}
