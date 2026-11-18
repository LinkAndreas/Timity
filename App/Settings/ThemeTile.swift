import SwiftUI

/// One icon in the app icon picker: its preview, its name, and a ring when it's chosen.
struct ThemeTile: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    private static let size: CGFloat = 64
    /// The Home Screen's corner shape, scaled to the preview.
    private static let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(theme.previewImageName)
                    .resizable()
                    .frame(width: Self.size, height: Self.size)
                    .clipShape(Self.shape)
                    .overlay {
                        Self.shape.strokeBorder(.separator, lineWidth: 0.5)
                    }
                    .padding(4)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Self.size * 0.225 + 4, style: .continuous)
                                .strokeBorder(theme.accentColor.color, lineWidth: 2.5)
                        }
                    }

                Text(theme.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        // Plain, so each icon is its own button rather than the whole row.
        .buttonStyle(.plain)
        .accessibilityLabel(Text(theme.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    HStack {
        ThemeTile(theme: .classic, isSelected: true) {}
        ThemeTile(theme: .ember, isSelected: false) {}
    }
    .padding()
}
#endif
