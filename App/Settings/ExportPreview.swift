import SwiftUI
import UniformTypeIdentifiers

/// What an export holds: a backup with or without photos, or a spreadsheet.
enum ExportKind: Hashable, CaseIterable {
    case backupWithPhotos, backupWithoutPhotos, spreadsheet

    var format: EventBackup.Format { self == .spreadsheet ? .csv : .json }
    var includesPhotos: Bool { self == .backupWithPhotos }

    var title: LocalizedStringKey {
        switch self {
        case .backupWithPhotos: "settings.backupWithPhotosJSON"
        case .backupWithoutPhotos: "settings.backupWithoutPhotosJSON"
        case .spreadsheet: "settings.spreadsheetCSV"
        }
    }

    var systemImage: String {
        switch self {
        case .backupWithPhotos: "doc.badge.gearshape"
        case .backupWithoutPhotos: "doc"
        case .spreadsheet: "tablecells"
        }
    }
}

/// An export before it leaves the app: which kind, the backup as text, the spreadsheet as
/// a table, with the file's name and size, and ways to save or share it.
struct ExportPreview: View {
    /// Every event as a file of the format; photos only in a JSON backup that asks for them.
    let export: (EventBackup.Format, _ includingPhotos: Bool) throws -> Data

    @Environment(\.dismiss) private var dismiss
    @State private var kind = ExportKind.backupWithPhotos
    @State private var document: BackupDocument?
    /// The file in the temporary folder, for sharing under its own name.
    @State private var sharedFile: URL?
    @State private var isSaving = false
    @State private var failure: String?

    /// Enough to see what's in the file without laying out a backup full of photos.
    private static let previewLimit = 20_000
    private static let rowLimit = 200

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ExportKindPicker(kind: $kind)
                if let document {
                    ExportHeader(document: document)
                    Divider()
                    switch document.format {
                    case .csv: ExportTable(document: document, rowLimit: Self.rowLimit)
                    case .json: ExportBackupText(document: document, previewLimit: Self.previewLimit)
                    }
                } else {
                    Spacer()
                }
            }
            .navigationTitle("settings.exportEvents")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveTitle, systemImage: "folder") { isSaving = true }
                        .disabled(document == nil)
                }
                if let sharedFile {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: sharedFile)
                    }
                }
            }
            .task(id: kind) { make(kind) }
            .fileExporter(
                isPresented: $isSaving,
                document: document,
                contentType: kind.format == .csv ? .commaSeparatedText : .json,
                defaultFilename: document?.fileName
            ) { result in
                switch result {
                case .success: dismiss()
                case let .failure(error): failure = error.localizedDescription
                }
            }
            .alert("settings.couldntSave", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure) { _ in
                Button("settings.ok", role: .cancel) {}
            } message: { failure in
                Text(failure)
            }
        }
        .macSheetSize(width: 720, height: 560)
    }

    /// The file for the kind, and a copy under its name for sharing.
    private func make(_ kind: ExportKind) {
        do {
            let made = BackupDocument(data: try export(kind.format, kind.includesPhotos), format: kind.format)
            document = made
            sharedFile = writeSharedFile(made)
        } catch {
            document = nil
            sharedFile = nil
            failure = error.localizedDescription
        }
    }

    private var saveTitle: LocalizedStringKey {
        #if os(macOS)
        "settings.saveToFiles.mac"
        #else
        "settings.saveToFiles"
        #endif
    }

    /// Writes the file under its name, so a shared copy arrives as "Timity Events 2026-10-18.csv".
    private func writeSharedFile(_ document: BackupDocument) -> URL? {
        let url = URL.temporaryDirectory.appending(path: document.fullFileName)
        do {
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Backup with or without photos, or a spreadsheet; the preview follows the choice.
private struct ExportKindPicker: View {
    @Binding var kind: ExportKind

    var body: some View {
        Picker("settings.exportEvents", selection: $kind) {
            ForEach(ExportKind.allCases, id: \.self) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

/// "Timity Events 2026-10-18.csv · 4 KB".
private struct ExportHeader: View {
    let document: BackupDocument

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: document.format == .csv ? "tablecells" : "doc.text")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: document.fullFileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Int64(document.data.count), format: .byteCount(style: .file))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if document.format == .json {
                    Text("settings.photosIncluded \(document.readable.photoCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Backup

/// The backup as text, its beginning when it's long.
private struct ExportBackupText: View {
    let document: BackupDocument
    let previewLimit: Int

    var body: some View {
        let full = document.readable.text
        let isShortened = full.count > previewLimit
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                if isShortened {
                    ShortenedNote()
                }
                Text(verbatim: isShortened ? String(full.prefix(previewLimit)) + "\n…" : full)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .fixedSize()
            }
            .padding()
        }
    }
}

// MARK: Spreadsheet

/// The spreadsheet as a table, its first rows when it's long.
private struct ExportTable: View {
    let document: BackupDocument
    let rowLimit: Int

    var body: some View {
        let rows = self.rows
        let shown = Array(rows.prefix(rowLimit + 1))
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                if rows.count > shown.count {
                    ShortenedNote()
                }
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { index, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, field in
                                Text(verbatim: field)
                                    .font(index == 0 ? .footnote.weight(.semibold) : .footnote)
                                    .foregroundStyle(index == 0 ? Color.secondary : Color.primary)
                                    .lineLimit(1)
                                    // As wide as the text, up to a limit, and the table scrolls sideways.
                                    .frame(maxWidth: 220, alignment: .leading)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        if index == 0 {
                            Divider()
                        }
                    }
                }
                .textSelection(.enabled)
            }
            .padding()
        }
    }

    private var rows: [[String]] {
        var text = String(decoding: document.data, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        // German spreadsheets use semicolons, as Excel there expects; the header shows which.
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let separator: Character = firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
        return EventBackup.parseCSV(text, separator: separator).filter { !$0.allSatisfy(\.isEmpty) }
    }
}

private struct ShortenedNote: View {
    var body: some View {
        Label("settings.previewShowsTheBeginning", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private extension BackupDocument {
    /// "Timity Events 2026-10-18.csv".
    var fullFileName: String {
        "\(fileName).\(format == .csv ? "csv" : "json")"
    }

    /// The backup as text, each photo as a short note of its size: a photo is one line of
    /// many thousand characters that would push everything else out of the preview.
    var readable: (text: String, photoCount: Int) {
        let text = String(decoding: data, as: UTF8.self)
        var count = 0
        let shortened = text.replacing(/"photo" : "([A-Za-z0-9+\/=]+)"/) { match in
            count += 1
            let bytes = Int64(match.output.1.count * 3 / 4)
            return "\"photo\" : \"‹\(String(localized: "settings.photo")), \(bytes.formatted(.byteCount(style: .file)))›\""
        }
        return (shortened, count)
    }
}
