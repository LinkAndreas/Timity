import SwiftUI
import UIKit

/// iCloud sync in detail: how it's doing, what's wrong if anything, and what helps.
struct CloudSyncView: View {
    @Binding var syncsWithICloud: Bool
    let state: () -> CloudSyncState
    let checkAgain: () async -> Void
    let repairs: CloudSyncRepairs
    /// Creates the CloudKit schema in development; debug builds only.
    let prepareSchema: (() async throws -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var checkCount = 0
    @State private var schemaResult: String?
    @State private var isPreparingSchema = false

    var body: some View {
        let state = state()

        Form {
            Section {
                Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
                CloudSyncStatusLabel(state: state)
                if let problem = state.problem {
                    Text(problem.advice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let details = state.problemDetails {
                        DisclosureGroup("common.details") {
                            Text(verbatim: details)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    if problem.isFixedInSettings {
                        Button("common.openSettings", systemImage: "gear") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
                // Only worth checking while sync isn't known to be working.
                if syncsWithICloud, state.problem != nil || state.account != .available {
                    Button(action: check) {
                        Label {
                            Text(isChecking ? LocalizedStringKey("sync.checkingICloud") : LocalizedStringKey("sync.checkAgain"))
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
                    ? "common.yourEventsSyncWithYour"
                    : "sync.yourEventsStayOnThis")
            }

            Section {
                ForEach(SyncSymptom.allCases) { symptom in
                    NavigationLink {
                        SyncProblemGuide(
                            symptom: symptom,
                            syncsWithICloud: $syncsWithICloud,
                            state: self.state,
                            checkAgain: checkAgain,
                            repairs: repairs
                        )
                    } label: {
                        Label { Text(symptom.title) } icon: { Image(systemName: symptom.systemImage) }
                    }
                }
                if let mail = SyncReport.mailURL(state: state, to: "feedback@linkandreas.de") {
                    Link(destination: mail) {
                        Label("sync.emailSupportWithASync", systemImage: "envelope")
                    }
                }
            } header: {
                Text("sync.needHelp")
            } footer: {
                Text("sync.pickWhatYouNoticeTimity")
            }

            if let prepareSchema {
            Section {
                Button {
                    Task {
                        isPreparingSchema = true
                        schemaResult = nil
                        do {
                            try await prepareSchema()
                            schemaResult = "Done. Deploy the schema to production in the CloudKit Console."
                        } catch {
                            schemaResult = Self.describe(error)
                        }
                        isPreparingSchema = false
                    }
                } label: {
                    Label {
                        Text(verbatim: isPreparingSchema ? "Preparing… This can take a minute." : "Prepare iCloud Schema")
                    } icon: {
                        if isPreparingSchema {
                            ProgressView()
                        } else {
                            Image(systemName: "hammer")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .disabled(isPreparingSchema)
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
            }
        }
        .navigationTitle("common.icloud")
        .navigationBarTitleDisplayMode(.inline)
        .task { await checkAgain() }
    }

    /// The error and every error it wraps, each on a line of its own: Core Data
    /// keeps CloudKit's reason in the errors underneath its own.
    static func describe(_ error: Error) -> String {
        var lines: [String] = []
        var current: NSError? = error as NSError
        while let error = current, lines.count < 5 {
            lines.append("\(error.domain) \(error.code): \(error.localizedDescription)")
            current = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return lines.joined(separator: "\n")
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
