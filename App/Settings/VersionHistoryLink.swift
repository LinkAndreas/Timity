import SwiftUI

/// The Settings row that opens the version history: a page pushed on iPhone and iPad, a
/// sheet on the Mac, where pages pushed in the Settings window would mix with its tabs.
struct VersionHistoryLink: View {
    /// Opens the sheet on the Mac.
    let showOnMac: () -> Void

    var body: some View {
        #if os(macOS)
        Button(action: showOnMac) {
            HStack {
                Label {
                    Text("settings.versionHistory")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.tint)
                }
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .rowButtonStyle()
        #else
        NavigationLink {
            VersionHistoryView()
        } label: {
            Label {
                Text("settings.versionHistory")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
        }
        #endif
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        Form {
            VersionHistoryLink {}
        }
    }
}
#endif
