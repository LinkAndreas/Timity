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
            .frame(maxWidth: 280)
            .padding(.vertical, 4)
    }
}
