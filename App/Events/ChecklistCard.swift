import SwiftUI

/// To-dos for an event, such as packing for a trip or gifts for a birthday,
/// synced with the event.
struct ChecklistCard: View {
    @Bindable var event: Event

    @State private var newItem = ""
    @FocusState private var isAdding: Bool

    var body: some View {
        let items = event.checklist

        Card(title: "Checklist") {
            if !items.isEmpty {
                let done = items.filter(\.isDone).count
                ProgressView(value: Double(done), total: Double(items.count)) {
                    Text("\(done) of \(items.count) done")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .tint(event.color.color)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Button {
                            toggle(item)
                        } label: {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.isDone ? AnyShapeStyle(event.color.color) : AnyShapeStyle(.secondary))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(item.title))
                        .accessibilityValue(item.isDone ? Text("Done") : Text("Not done"))

                        Text(item.title)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityHidden(true)
                    }
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { remove(item) }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    TextField("Add an Item", text: $newItem)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
            }
            .sensoryFeedback(.selection, trigger: items.filter(\.isDone).count)
        }
    }

    private func add() {
        let title = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        withAnimation { event.checklist.append(ChecklistItem(title: title)) }
        event.modifiedAt = .now
        newItem = ""
        // Keep typing the next item.
        isAdding = true
    }

    private func toggle(_ item: ChecklistItem) {
        var items = event.checklist
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        withAnimation { event.checklist = items }
        event.modifiedAt = .now
    }

    private func remove(_ item: ChecklistItem) {
        withAnimation { event.checklist.removeAll { $0.id == item.id } }
        event.modifiedAt = .now
    }
}
