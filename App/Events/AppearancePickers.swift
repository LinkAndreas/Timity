import SwiftUI

/// The event colours as swatches.
struct ColorPalette: View {
    @Binding var selection: EventColor

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 44), spacing: 10)], spacing: 10) {
            ForEach(EventColor.allCases) { color in
                Button {
                    withAnimation(.snappy) { selection = color }
                } label: {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 34, height: 34)
                        .overlay {
                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(3)
                        .overlay {
                            Circle()
                                .strokeBorder(selection == color ? color.color : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.name))
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A grid of SF Symbols for the event's badge, with search.
struct SymbolPicker: View {
    @Binding var selection: String
    let color: EventColor

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(filteredGroups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                            ForEach(group.symbols, id: \.self) { symbol in
                                Button {
                                    selection = symbol
                                    dismiss()
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.title2)
                                        .frame(width: 52, height: 52)
                                        .foregroundStyle(selection == symbol ? .white : color.color)
                                        .background {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(selection == symbol ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.fill.tertiary))
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(symbol.replacingOccurrences(of: ".", with: " ")))
                                .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Symbol")
        .searchable(text: $searchText, prompt: "Search Symbols")
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var filteredGroups: [(title: LocalizedStringResource, symbols: [String])] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return EventSymbol.groups }
        return EventSymbol.groups.compactMap { group in
            let symbols = group.symbols.filter { $0.replacingOccurrences(of: ".", with: " ").contains(query) }
            return symbols.isEmpty ? nil : (group.title, symbols)
        }
    }
}
