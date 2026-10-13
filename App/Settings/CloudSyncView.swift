import SwiftUI
import UIKit

/// iCloud sync in detail: how it's doing, what's wrong if anything, and what helps.
struct CloudSyncView: View {
    @Binding var syncsWithICloud: Bool
    let state: () -> CloudSyncState
    let checkAgain: () async -> Void
    #if DEBUG
    let prepareSchema: () throws -> Void
    #endif

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false
    #if DEBUG
    @State private var schemaResult: String?
    #endif

    var body: some View {
        let state = state()

        Form {
            Section {
                Toggle("Sync with iCloud", isOn: $syncsWithICloud)
                CloudSyncStatusLabel(state: state)
                if let problem = state.problem {
                    Text(problem.advice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if problem.isFixedInSettings {
                        Button("Open Settings", systemImage: "gear") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
                if syncsWithICloud {
                    Button {
                        Task {
                            isChecking = true
                            await checkAgain()
                            isChecking = false
                        }
                    } label: {
                        Label(isChecking ? LocalizedStringKey("Checking iCloud…") : LocalizedStringKey("Check Again"), systemImage: "arrow.clockwise")
                    }
                    .disabled(isChecking)
                }
            } footer: {
                Text(syncsWithICloud
                    ? "Your events sync with your iPhone, iPad and Apple Watch through your private iCloud account. Only you can see them."
                    : "Your events stay on this device. Turn sync back on at any time; events from both sides are kept.")
            }

            Section("If Events Don't Appear") {
                Tip(symbol: "person.crop.circle", text: "Use the same Apple Account on all your devices.")
                Tip(symbol: "checkmark.icloud", text: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud.")
                Tip(symbol: "wifi", text: "Syncing can pause without a connection or in Low Power Mode. Open Timity and give it a moment.")
                Tip(symbol: "arrow.triangle.2.circlepath", text: "Still stuck? Turn Sync with iCloud off and on again. Your events stay on this device.")
            }

            #if DEBUG
            Section {
                Button("Prepare iCloud Schema", systemImage: "hammer") {
                    do {
                        try prepareSchema()
                        schemaResult = "Done. Deploy the schema to production in the CloudKit Console."
                    } catch {
                        schemaResult = error.localizedDescription
                    }
                }
                if let schemaResult {
                    Text(verbatim: schemaResult)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(verbatim: "Developer")
            } footer: {
                Text(verbatim: "Creates every event field in the development environment. App Store and TestFlight builds only sync once that schema is deployed to production.")
            }
            #endif
        }
        .navigationTitle("iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkAgain() }
    }
}

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

private struct Tip: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
        }
    }
}

extension CloudSyncState.Problem {
    var title: LocalizedStringResource {
        switch self {
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
        case .noAccount: "Sign in with your Apple Account in Settings to sync your events."
        case .restricted: "Screen Time or a device profile keeps Timity from using iCloud."
        case .unavailable: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud."
        case .offline: "Your events sync once this device is online again."
        case .storageFull: "Free up space or add iCloud storage to sync again. Your events stay on this device meanwhile."
        case .rejected: "Your events are safe on this device and sync as soon as iCloud accepts them. An update to Timity usually fixes this; if it keeps happening, please send feedback."
        case let .other(message): message.isEmpty ? "Timity tries again shortly." : "\(message)"
        }
    }

    var isFixedInSettings: Bool {
        switch self {
        case .noAccount, .unavailable, .storageFull: true
        default: false
        }
    }
}
