import Foundation

/// Links shown with the purchase options, as App Review requires for subscriptions.
/// The terms are Apple's Standard License Agreement; the privacy policy is published
/// in the app's languages and opens in the language the app runs in.
enum SupportLinks {
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
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
