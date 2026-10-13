import SwiftUI

/// One line on how sync is doing.
struct CloudSyncStatusLabel: View {
    let state: CloudSyncState

    var body: some View {
        Label {
            state.statusText
        } icon: {
            Image(systemName: state.statusSymbol)
                .symbolEffect(.pulse, isActive: state.isSyncing)
        }
        .modifier(StatusTint(tint: state.statusTint))
    }
}

/// Colours the status only when it has a colour of its own, so a quiet status
/// takes the style around it.
private struct StatusTint: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if let tint { content.foregroundStyle(tint) } else { content }
    }
}

extension CloudSyncState {
    var statusText: Text {
        if !isEnabled { return Text("Off — events stay on this device") }
        if isSyncing { return Text("Syncing…") }
        if let problem { return Text(problem.title) }
        if let lastSynced { return Text("Synced \(lastSynced, format: .relative(presentation: .named))") }
        if account == .available { return Text("Syncing with iCloud") }
        return Text("Checking iCloud…")
    }

    var statusSymbol: String {
        if !isEnabled { return "icloud.slash" }
        if isSyncing { return "arrow.trianglehead.2.clockwise.rotate.90.icloud" }
        if let problem { return problem == .offline ? "icloud.slash" : "exclamationmark.icloud" }
        if lastSynced != nil || account == .available { return "checkmark.icloud" }
        return "icloud"
    }

    /// Orange for a problem, grey while off, offline or still checking; `nil`
    /// when all is well.
    var statusTint: Color? {
        if !isEnabled { return .secondary }
        if isSyncing { return nil }
        if let problem { return problem == .offline ? .secondary : .orange }
        if lastSynced != nil || account == .available { return nil }
        return .secondary
    }
}

extension CloudSyncState.Problem {
    var title: LocalizedStringResource {
        switch self {
        case .couldNotStart: "iCloud Sync Couldn't Start"
        case .noAccount: "Not Signed In to iCloud"
        case .restricted: "iCloud Is Restricted"
        case .unavailable: "iCloud Isn't Available"
        case .offline: "Waiting for a Connection"
        case .storageFull: "iCloud Storage Is Full"
        case .rejected: "Can't Sync with iCloud Right Now"
        case .other: "Sync Paused"
        }
    }

    var advice: LocalizedStringResource {
        switch self {
        case .couldNotStart: "Your events are safe on this device. Quit and reopen Timity to try again; if it keeps happening, please send feedback."
        #if os(watchOS)
        case .noAccount: "Sign in to iCloud on your iPhone to sync your events."
        #else
        case .noAccount: "Sign in with your Apple Account in Settings to sync your events."
        #endif
        case .restricted: "Screen Time or a device profile keeps Timity from using iCloud."
        #if os(watchOS)
        case .unavailable: "On your iPhone, open Settings, tap your name, then iCloud, and check that Timity may use iCloud."
        #else
        case .unavailable: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud."
        #endif
        case .offline: "Your events sync once this device is online again."
        case .storageFull: "Free up space or add iCloud storage to sync again. Your events stay on this device meanwhile."
        case .rejected: "Your events are safe on this device and sync as soon as iCloud accepts them. An update to Timity usually fixes this; if it keeps happening, please send feedback."
        case .other: "Timity tries again shortly. If it keeps happening, please send feedback with the details below."
        }
    }

    var isFixedInSettings: Bool {
        switch self {
        case .noAccount, .unavailable, .storageFull: true
        default: false
        }
    }
}
