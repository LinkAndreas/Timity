import Foundation

/// Emails to the developer, with what's needed to help below the user's text:
/// the app, system, device and language. No events or personal details go in them.
enum SupportMail {
    static let address = "feedback@linkandreas.de"

    /// A feedback email, room left at the top for the user's words.
    static var feedbackURL: URL? {
        url(subject: "Timity", details: [])
    }

    /// An email with `details` below the app and device line.
    static func url(subject: String, details: [String]) -> URL? {
        let lines = ["", "", "———", deviceLine] + details
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: lines.joined(separator: "\n")),
        ]
        return components.url
    }

    /// "Timity 4.9.0 (210) · iOS 27.0 · iPhone18,1 · de-DE".
    @MainActor
    static var deviceLine: String {
        let language = Locale.preferredLanguages.first ?? Locale.current.identifier
        return "Timity \(Bundle.main.versionDescription) · \(Platform.deviceDescription.system) · \(DeviceModel.identifier) · \(language)"
    }
}

nonisolated enum DeviceModel {
    /// "iPhone18,1", which tells models apart where `UIDevice.model` only says "iPhone".
    static var identifier: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
