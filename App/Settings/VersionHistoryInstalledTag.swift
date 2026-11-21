import SwiftUI

/// A small tag on the release that's the one on this device.
struct VersionHistoryInstalledTag: View {
    var body: some View {
        Text("versionHistory.installed")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.tint.opacity(0.15), in: .capsule)
    }
}

#if DEBUG
#Preview {
    VersionHistoryInstalledTag()
        .padding()
}
#endif
