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
    @State private var checkCount = 0
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
                    if let details = state.problemDetails {
                        DisclosureGroup("Details") {
                            Text(verbatim: details)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    if problem.isFixedInSettings {
                        Button("Open Settings", systemImage: "gear") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
                // Only worth checking while sync isn't known to be working.
                if syncsWithICloud, state.problem != nil || state.account != .available {
                    Button(action: check) {
                        Label {
                            Text(isChecking ? LocalizedStringKey("Checking iCloud…") : LocalizedStringKey("Check Again"))
                        } icon: {
                            if isChecking {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                    .disabled(isChecking)
                    .sensoryFeedback(.success, trigger: checkCount)
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

    /// Checks again, showing it for at least a moment: a check that answers at
    /// once would otherwise look like a tap that did nothing.
    private func check() {
        Task {
            isChecking = true
            async let minimumDuration: Void = (try? await Task.sleep(for: .milliseconds(800))) ?? ()
            await checkAgain()
            await minimumDuration
            isChecking = false
            checkCount += 1
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
