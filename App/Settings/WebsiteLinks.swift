import Foundation

/// Pages on Timity's website. The privacy policy is published in the app's languages
/// and opens in the language the app runs in.
enum WebsiteLinks {
    static let home = URL(string: "https://timity.linkandreas.de")!
    static var privacyPolicy: URL { page("privacy") }

    /// The app's languages, each with its own page; any other language gets English.
    private static let languages: Set<String> = ["de", "en", "es", "fr"]

    private static func page(_ name: String) -> URL {
        let language = Bundle.main.preferredLocalizations.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
            .flatMap { languages.contains($0) ? $0 : nil } ?? "en"
        return URL(string: "https://timity.linkandreas.de/\(name)/\(language)/")!
    }
}
