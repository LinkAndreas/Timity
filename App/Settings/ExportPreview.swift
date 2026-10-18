import SwiftUI
import UniformTypeIdentifiers

/// An export before it leaves the app: the backup as text, the spreadsheet as a table,
/// with the file's name and size, and ways to save or share it.
struct ExportPreview: View {
    let document: BackupDocument

    @Environment(\.dismiss) private var dismiss
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
                header
                Divider()
                switch document.format {
                case .csv: table
                case .json: text
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
                }
                if let sharedFile {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: sharedFile)
                    }
                }
            }
            .task { sharedFile = writeSharedFile() }
            .fileExporter(
                isPresented: $isSaving,
                document: document,
                contentType: document.contentType,
                defaultFilename: document.fileName
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

    private var saveTitle: LocalizedStringKey {
        #if os(macOS)
        "settings.saveToFiles.mac"
        #else
        "settings.saveToFiles"
        #endif
    }

    /// "Timity Events 2026-10-18.csv · 4 KB".
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: document.format == .csv ? "tablecells" : "doc.text")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Int64(document.data.count), format: .byteCount(style: .file))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if document.format == .json {
                    Text("settings.photosIncluded \(readable.photoCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var fileName: String {
        "\(document.fileName).\(document.format == .csv ? "csv" : "json")"
    }

    // MARK: Backup

    private var text: some View {
        let full = readable.text
        let isShortened = full.count > Self.previewLimit
        return ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                if isShortened {
                    shortenedNote
                }
                Text(verbatim: isShortened ? String(full.prefix(Self.previewLimit)) + "\n…" : full)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .fixedSize()
            }
            .padding()
        }
    }

    /// The backup as text, each photo as a short note of its size: a photo is one line of
    /// many thousand characters that would push everything else out of the preview.
    private var readable: (text: String, photoCount: Int) {
        let text = String(decoding: document.data, as: UTF8.self)
        var count = 0
        let shortened = text.replacing(/"photo" : "([A-Za-z0-9+\/=]+)"/) { match in
            count += 1
            let bytes = Int64(match.output.1.count * 3 / 4)
            return "\"photo\" : \"‹\(String(localized: "settings.photo")), \(bytes.formatted(.byteCount(style: .file)))›\""
        }
        return (shortened, count)
    }

    // MARK: Spreadsheet

    private var table: some View {
        var text = String(decoding: document.data, as: UTF8.self)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        // German spreadsheets use semicolons, as Excel there expects; the header shows which.
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let separator: Character = firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
        let rows = EventBackup.parseCSV(text, separator: separator).filter { !$0.allSatisfy(\.isEmpty) }
        let shown = Array(rows.prefix(Self.rowLimit + 1))

        return ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                if rows.count > shown.count {
                    shortenedNote
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

    private var shortenedNote: some View {
        Label("settings.previewShowsTheBeginning", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// Writes the file under its name, so a shared copy arrives as "Timity Events 2026-10-18.csv".
    private func writeSharedFile() -> URL? {
        let url = URL.temporaryDirectory.appending(path: fileName)
        do {
            try document.data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
