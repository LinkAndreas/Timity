import SwiftUI

/// Every release of Timity, newest first, with what each one brought.
struct VersionHistoryView: View {
    var body: some View {
        Form {
            ForEach(VersionHistory.releases) { release in
                Section {
                    VersionHistoryReleaseRow(release: release)
                }
            }
        }
        .navigationTitle("settings.versionHistory")
        .inlineNavigationTitle()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        VersionHistoryView()
    }
}
#endif
