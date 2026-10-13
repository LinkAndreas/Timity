import SwiftUI

/// One line on how sync is doing.
struct CloudSyncStatusLabel: View {
    let state: CloudSyncState

    var body: some View {
        if !state.isEnabled {
            Label("Off — events stay on this device", systemImage: "icloud.slash")
                .foregroundStyle(Color.secondary)
        } else if state.isSyncing {
            Label("Syncing…", systemImage: "arrow.trianglehead.2.clockwise.rotate.90.icloud")
                .symbolEffect(.pulse)
        } else if let problem = state.problem {
            Label(problem.title, systemImage: problem == .offline ? "icloud.slash" : "exclamationmark.icloud")
                .foregroundStyle(problem == .offline ? Color.secondary : Color.orange)
        } else if let lastSynced = state.lastSynced {
            Label {
                Text("Synced \(lastSynced, format: .relative(presentation: .named))")
            } icon: {
                Image(systemName: "checkmark.icloud")
            }
        } else if state.account == .available {
            Label("Syncing with iCloud", systemImage: "checkmark.icloud")
        } else {
            Label("Checking iCloud…", systemImage: "icloud")
                .foregroundStyle(Color.secondary)
        }
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
        case .noAccount: "Sign in with your Apple Account in Settings to sync your events."
        case .restricted: "Screen Time or a device profile keeps Timity from using iCloud."
        case .unavailable: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud."
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
