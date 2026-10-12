import Foundation

/// The `timity://` links widgets and notifications open.
enum DeepLink {
    static let newEvent = URL(string: "timity://new")!

    static func event(_ id: UUID) -> URL {
        URL(string: "timity://event/\(id.uuidString)")!
    }

    /// The event a link points to, if any.
    static func eventID(in url: URL) -> UUID? {
        guard url.scheme == "timity", url.host() == "event" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
