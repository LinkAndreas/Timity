import SwiftUI

/// An event's symbol on its colour, in the shape of an app icon.
struct EventBadge: View {
    let symbolName: String
    let color: EventColor
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay {
                // Decoration: the event's name beside it says what it is.
                Image(systemName: symbolName)
                    .accessibilityHidden(true)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    EventBadge(
        symbolName: "cross",
        color: .green,
        size: 42.0
    )
    .padding()
}
