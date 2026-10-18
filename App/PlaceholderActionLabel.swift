import SwiftUI

/// The label of a button on an empty or waiting screen: large, and as wide as the
/// others, so buttons stacked one above the other line up.
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
            .frame(maxWidth: 280)
            .padding(.vertical, 4)
    }
}
