import SwiftUI

// With the iPhone on its side the screen is wide but short, so screens that
// stack their content in portrait set it side by side, as TestFlight does.
// The iPad keeps its own layout: its height is never compact.

/// A grouped form, or two forms side by side when the screen is short: what
/// you enter on the left, what it comes to on the right.
struct SideBySideForm<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if verticalSizeClass == .compact {
            HStack(alignment: .top, spacing: 0) {
                Form { leading }
                Form { trailing }
            }
        } else {
            Form {
                leading
                trailing
            }
        }
    }
}

/// Content on the grouped card the list rows use, filling its grid cell.
struct GridCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // As tall as the tallest card in its row.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
            .contentShape(.rect(cornerRadius: 26))
    }
}

extension View {
    func gridCard() -> some View {
        modifier(GridCard())
    }
}

/// A titled group of cards, two or more to a row, like a list section.
struct GridSection<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.leading)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                content
            }
        }
    }
}
