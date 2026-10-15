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

    @State private var document: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var outcome: EventBackup.Outcome?
    @State private var failure: String?

    var body: some View {
        Menu {
            Button("Backup with Photos (JSON)", systemImage: "doc.badge.gearshape") { export(.json, includingPhotos: true) }
            Button("Backup without Photos (JSON)", systemImage: "doc") { export(.json, includingPhotos: false) }
            Button("Spreadsheet (CSV)", systemImage: "tablecells") { export(.csv, includingPhotos: false) }
        } label: {
            Label("Export Events", systemImage: "square.and.arrow.up")
        }
        Button("Import from a File", systemImage: "doc.badge.plus") {
            isImporting = true
        }
        .fileExporter(
            isPresented: $isExporting,
            document: document,
            contentType: document?.contentType ?? .json,
            defaultFilename: document?.fileName
        ) { result in
            if case let .failure(error) = result { failure = error.localizedDescription }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .commaSeparatedText, .plainText, .timityEvent]) { result in
            importFile(result)
        }
        .alert("Import Finished", isPresented: Binding(get: { outcome != nil }, set: { if !$0 { outcome = nil } }), presenting: outcome) { _ in
            Button("OK", role: .cancel) {}
        } message: { outcome in
            Text(Self.summary(outcome))
        }
        .alert("Couldn't Import", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure)
        }
        .sensoryFeedback(.success, trigger: outcome) { _, new in new != nil }
    }

    private func export(_ format: EventBackup.Format, includingPhotos: Bool) {
        do {
            document = BackupDocument(data: try actions.export(format, includingPhotos), format: format)
            isExporting = true
        } catch {
            failure = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            outcome = try actions.importFile(Data(contentsOf: url))
        } catch EventBackup.ImportError.unreadable {
            failure = String(localized: "The file isn't a Timity backup, a Timity event or a spreadsheet with Title and Date columns.")
        } catch {
            failure = error.localizedDescription
        }
    }

    /// "3 added, 1 updated, 12 already here."
    static func summary(_ outcome: EventBackup.Outcome) -> String {
        var parts = [String(localized: "\(outcome.added) added"), String(localized: "\(outcome.updated) updated")]
        if outcome.unchanged > 0 { parts.append(String(localized: "\(outcome.unchanged) already here")) }
        if outcome.skipped > 0 { parts.append(String(localized: "\(outcome.skipped) rows skipped")) }
        return parts.formatted(.list(type: .and))
    }
}

/// An exported file, for the system's save panel.
struct BackupDocument: FileDocument {
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
        "\(String(localized: "Timity Events")) \(Date.now.formatted(.iso8601.year().month().day()))"
    }
}
