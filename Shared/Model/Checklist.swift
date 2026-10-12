import Foundation

/// A to-do on an event, such as "Book the hotel" for a trip.
struct ChecklistItem: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var isDone = false
}

enum Checklist {
    static func decode(_ data: Data?) -> [ChecklistItem] {
        data.flatMap { try? JSONDecoder().decode([ChecklistItem].self, from: $0) } ?? []
    }

    static func encode(_ items: [ChecklistItem]) -> Data? {
        items.isEmpty ? nil : try? JSONEncoder().encode(items)
    }
}
