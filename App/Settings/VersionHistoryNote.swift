import SwiftUI

/// One point of a release's notes, after a bullet.
struct VersionHistoryNote: View {
    let text: LocalizedStringResource

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "•")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
    }
}

#if DEBUG
#Preview {
    VersionHistoryNote(text: "versionHistory.4_10_0.note1")
        .padding()
}
#endif
