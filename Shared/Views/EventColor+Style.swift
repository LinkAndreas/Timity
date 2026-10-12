import SwiftUI

extension EventColor {
    /// The colour's main tone, for tints and small marks.
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .graphite: Color(red: 0.42, green: 0.45, blue: 0.5)
        case .sunrise: Color(red: 1.0, green: 0.45, blue: 0.3)
        case .aurora: Color(red: 0.2, green: 0.75, blue: 0.6)
        case .lagoon: Color(red: 0.1, green: 0.6, blue: 0.85)
        case .blossom: Color(red: 0.95, green: 0.45, blue: 0.7)
        case .ember: Color(red: 0.85, green: 0.25, blue: 0.2)
        case .nightfall: Color(red: 0.3, green: 0.25, blue: 0.65)
        }
    }

    /// The fill for cards, heroes and widgets: a soft gradient of the colour, or
    /// for the gradient colours a blend of two hues.
    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var gradientColors: [Color] {
        switch self {
        case .sunrise: [Color(red: 1.0, green: 0.75, blue: 0.3), Color(red: 0.95, green: 0.3, blue: 0.4)]
        case .aurora: [Color(red: 0.3, green: 0.9, blue: 0.6), Color(red: 0.25, green: 0.35, blue: 0.85)]
        case .lagoon: [Color(red: 0.2, green: 0.85, blue: 0.85), Color(red: 0.1, green: 0.35, blue: 0.75)]
        case .blossom: [Color(red: 1.0, green: 0.7, blue: 0.75), Color(red: 0.75, green: 0.3, blue: 0.75)]
        case .ember: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.7, green: 0.1, blue: 0.2)]
        case .nightfall: [Color(red: 0.35, green: 0.3, blue: 0.75), Color(red: 0.08, green: 0.1, blue: 0.3)]
        default: [color.mix(with: .white, by: 0.15), color.mix(with: .black, by: 0.2)]
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .teal: "Teal"
        case .cyan: "Cyan"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .brown: "Brown"
        case .graphite: "Graphite"
        case .sunrise: "Sunrise"
        case .aurora: "Aurora"
        case .lagoon: "Lagoon"
        case .blossom: "Blossom"
        case .ember: "Ember"
        case .nightfall: "Nightfall"
        }
    }
}

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
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
            .accessibilityHidden(true)
    }
}
