import Foundation

/// Pages on Timity's website. The privacy policy is published in the app's languages
/// and opens in the language the app runs in.
enum WebsiteLinks {
    static let home = URL(string: "https://timity.linkandreas.de")!
    static var privacyPolicy: URL { page("privacy") }

    /// The website's path for each of the app's languages, by language code; any other
    /// language gets English. Brazilian Portuguese is "pt-br" there, Simplified Chinese "zh".
    private static let languages: [String: String] = [
        "de": "de", "en": "en", "es": "es", "fr": "fr", "it": "it", "ja": "ja", "ko": "ko", "nl": "nl", "pt": "pt-br", "ru": "ru", "zh": "zh",
    ]

    private static func page(_ name: String) -> URL {
        let language = Bundle.main.preferredLocalizations.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
            .flatMap { languages[$0] } ?? "en"
        return URL(string: "https://timity.linkandreas.de/\(name)/\(language)/")!
    }
}
