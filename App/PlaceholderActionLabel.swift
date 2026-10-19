import SwiftUI

/// The label of the one prominent button on an empty or waiting screen: large, and
/// as wide as its title, as on Apple's own empty screens.
struct PlaceholderActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            // Long titles, as "Geburtstage und Termine importieren", go on to a second
            // line rather than being cut short.
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
    }
}
