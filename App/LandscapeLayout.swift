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
    @Environment(\.usesResultColumn) private var usesResultColumn

    var body: some View {
        if usesResultColumn {
            // The window has a column for the result: what's asked stays here, the answer goes there.
            Form { leading }
                .resultColumn { Form { trailing } }
        } else if verticalSizeClass == .compact {
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

extension EnvironmentValues {
    /// Whether the window has a last column for a calculator's result or the sky, as the Mac's and
    /// the iPad's three columns do; otherwise a section shows everything itself.
    @Entry var usesResultColumn = false
}

/// What a section shows in the last column of the window: a calculator's result, or the
/// sky over the place chosen. The section hands it up from the middle column, where its own
/// state lives, and the window draws it in the last.
struct ResultColumnContent: Equatable, @unchecked Sendable {
    let id = UUID()
    let view: AnyView

    // A new one each time the section draws, so the last column follows every change.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

struct ResultColumnKey: PreferenceKey {
    static let defaultValue: ResultColumnContent? = nil

    static func reduce(value: inout ResultColumnContent?, nextValue: () -> ResultColumnContent?) {
        value = nextValue() ?? value
    }
}

/// Holds what the last column shows. Only that column reads it, so a change redraws it alone,
/// not the section that handed it up, which would hand up a new one again.
@MainActor
@Observable
final class ResultColumnModel {
    var content: ResultColumnContent?
}

/// The last column of the window, drawing what the section handed up.
struct ResultColumn: View {
    let model: ResultColumnModel

    var body: some View {
        if let content = model.content {
            content.view
        } else {
            Color.clear
        }
    }
}

extension View {
    /// Shows `result` in the last column of the window, beside this view in the middle one.
    func resultColumn<Result: View>(@ViewBuilder _ result: () -> Result) -> some View {
        preference(key: ResultColumnKey.self, value: ResultColumnContent(view: AnyView(result())))
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
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                content
            }
        }
    }
}
