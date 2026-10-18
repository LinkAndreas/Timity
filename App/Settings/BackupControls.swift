import SwiftUI
import UniformTypeIdentifiers

/// What Settings needs to export and import events.
struct BackupActions {
    /// Every event as a file of the format; photos only in a JSON backup that asks for them.
    let export: (EventBackup.Format, _ includingPhotos: Bool) throws -> Data
    /// Adds the file's events and updates changed ones.
    let importFile: (Data) throws -> EventBackup.Outcome
}

/// Export to a backup or a spreadsheet, and import either again — in Settings.
struct BackupControls: View {
    let actions: BackupActions

    /// The export shown before it's saved or shared.
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var outcome: EventBackup.Outcome?
    @State private var failure: String?

    var body: some View {
        // A button that opens the preview, as Import Birthdays and Events opens its screen;
        // the kind of file is picked there.
        Button("settings.exportEvents", systemImage: "square.and.arrow.up") {
            isExporting = true
        }
        Button("settings.importFromAFile", systemImage: "doc.badge.plus") {
            isImporting = true
        }
        .sheet(isPresented: $isExporting) {
            ExportPreview(export: actions.export)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .commaSeparatedText, .plainText, .timityEvent]) { result in
            importFile(result)
        }
        .alert("settings.importFinished", isPresented: Binding(get: { outcome != nil }, set: { if !$0 { outcome = nil } }), presenting: outcome) { _ in
            Button("settings.ok", role: .cancel) {}
        } message: { outcome in
            Text(Self.summary(outcome))
        }
        .alert("settings.couldntImport", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure) { _ in
            Button("settings.ok", role: .cancel) {}
        } message: { failure in
            Text(failure)
        }
        .sensoryFeedback(.success, trigger: outcome) { _, new in new != nil }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            outcome = try actions.importFile(Data(contentsOf: url))
        } catch EventBackup.ImportError.unreadable {
            failure = String(localized: "settings.theFileIsntATimity")
        } catch {
            failure = error.localizedDescription
        }
    }

    /// "3 added, 1 updated, 12 already here."
    static func summary(_ outcome: EventBackup.Outcome) -> String {
        var parts = [String(localized: "settings.added \(outcome.added)"), String(localized: "settings.updated \(outcome.updated)")]
        if outcome.unchanged > 0 { parts.append(String(localized: "settings.alreadyHere \(outcome.unchanged)")) }
        if outcome.skipped > 0 { parts.append(String(localized: "settings.rowsSkipped \(outcome.skipped)")) }
        return parts.formatted(.list(type: .and))
    }
}

/// An exported file, for the system's save panel.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data
    var format: EventBackup.Format

    init(data: Data, format: EventBackup.Format) {
        self.data = data
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        format = configuration.contentType == .commaSeparatedText ? .csv : .json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    var contentType: UTType { format == .csv ? .commaSeparatedText : .json }

    /// "Timity Events 2026-10-15".
    var fileName: String {
        "\(String(localized: "settings.timityEvents")) \(Date.now.formatted(.iso8601.year().month().day()))"
    }
}
