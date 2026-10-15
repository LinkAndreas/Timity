import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// A Timity event, declared in Info.plist as a JSON file with the `.timity` extension.
    static let timityEvent = UTType(exportedAs: EventFile.typeIdentifier, conformingTo: .json)
}

/// An event shared as a `.timity` file. Whoever receives it can add it to their Timity.
nonisolated struct EventFileTransfer: Transferable {
    let file: EventFile

    init(event: EventSnapshot) {
        file = EventFile(event, notes: event.notes)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .timityEvent) { transfer in
            try transfer.file.encoded()
        }
        .suggestedFileName { $0.file.fileName }
    }
}

nonisolated extension EventDraft {
    /// A new event's values from a received file.
    init(_ file: EventFile) {
        self.init()
        title = file.title
        isAllDay = file.isAllDay
        date = file.isAllDay ? FloatingDay.localDate(fromStored: file.date) : file.date
        recurrence = Recurrence(rawValue: file.recurrence) ?? .never
        color = EventColor(rawValue: file.color) ?? .orange
        symbolName = file.symbolName
        notes = file.notes
        timeZoneIdentifier = file.timeZoneIdentifier
        isYearUnknown = file.isYearUnknown
        imageData = file.imageData
        recurrenceInterval = max(1, file.recurrenceInterval ?? 1)
        recurrencePattern = file.recurrencePattern.flatMap(RecurrenceRule.Pattern.init(rawValue:)) ?? .sameDay
        eventCalendar = file.eventCalendar.flatMap(EventCalendar.init(rawValue:))
    }
}

/// Reads a `.timity` file the user opened, e.g. from Messages or Files.
nonisolated enum ReceivedEventFile {
    static func draft(at url: URL) throws -> EventDraft {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
        return EventDraft(try EventFile.decode(Data(contentsOf: url)))
    }
}
