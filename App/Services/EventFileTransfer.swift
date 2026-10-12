import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A Timity event, declared in Info.plist as a JSON file with the `.timity` extension.
    static let timityEvent = UTType(exportedAs: EventFile.typeIdentifier, conformingTo: .json)
}

/// An event shared as a `.timity` file. Whoever receives it can add it to their Timity.
struct EventFileTransfer: Transferable {
    let file: EventFile

    init(event: Event) {
        file = EventFile(event.snapshot, notes: event.notes)
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .timityEvent) { transfer in
            try transfer.file.encoded()
        }
        .suggestedFileName { $0.file.fileName }
    }
}

extension EventDraft {
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
    }
}
