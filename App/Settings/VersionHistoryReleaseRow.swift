import SwiftUI

/// One release: its version and month, a tag when it's the one installed, and its notes.
struct VersionHistoryReleaseRow: View {
    let release: VersionHistory.Release

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("versionHistory.version \(release.version)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if release.isInstalled {
                    VersionHistoryInstalledTag()
                }
                Spacer(minLength: 8)
                Text(release.date, format: .dateTime.month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(release.notes.indices, id: \.self) { index in
                    VersionHistoryNote(text: release.notes[index])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    Form {
        Section {
            VersionHistoryReleaseRow(release: VersionHistory.releases[0])
        }
    }
}
#endif
