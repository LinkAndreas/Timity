import SwiftUI
import UIKit

/// iCloud sync in detail: how it's doing, what's wrong if anything, and what helps.
struct CloudSyncView: View {
    /// Ways out when this device and iCloud don't agree.
    struct Repairs {
        /// Replaces this device's events with iCloud's.
        let downloadAgain: () async throws -> Void
        /// Replaces iCloud's events with this device's.
        let uploadAgain: () async throws -> Void
        /// Deletes the events from iCloud and turns sync off, keeping them here.
        let removeFromICloud: () async throws -> Void
    }

    private enum Repair: Identifiable {
        case downloadAgain, uploadAgain, removeFromICloud
        var id: Self { self }
    }

    @Binding var syncsWithICloud: Bool
    let state: () -> CloudSyncState
    let checkAgain: () async -> Void
    let repairs: Repairs
    /// Creates the CloudKit schema in development; debug builds only.
    let prepareSchema: (() async throws -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var checkCount = 0
    @State private var confirming: Repair?
    @State private var running: Repair?
    @State private var repairResult: LocalizedStringResource?
    @State private var repairError: String?
    @State private var schemaResult: String?
    @State private var isPreparingSchema = false

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

            if syncsWithICloud || running != nil || repairResult != nil {
                repairSection(canReachICloud: state.account == .available)
            }

            Section("If Events Don't Appear") {
                Tip(symbol: "person.crop.circle", text: "Use the same Apple Account on all your devices.")
                Tip(symbol: "checkmark.icloud", text: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud.")
                Tip(symbol: "wifi", text: "Syncing can pause without a connection or in Low Power Mode. Open Timity and give it a moment.")
                Tip(symbol: "arrow.triangle.2.circlepath", text: "Still stuck? Turn Sync with iCloud off and on again. Your events stay on this device.")
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
        .navigationTitle("iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            confirming.map(confirmationTitle) ?? "",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { repair in
            Button(actionTitle(repair), role: .destructive) { run(repair) }
        } message: { repair in
            Text(confirmationMessage(repair))
        }
        .task { await checkAgain() }
    }

    // MARK: Repairs

    private func repairSection(canReachICloud: Bool) -> some View {
        Section {
            repairButton(.downloadAgain, systemImage: "icloud.and.arrow.down")
            repairButton(.uploadAgain, systemImage: "icloud.and.arrow.up")
            repairButton(.removeFromICloud, systemImage: "xmark.icloud")
            if let repairResult {
                Text(repairResult)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let repairError {
                Text(verbatim: repairError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Fix Sync Problems")
        } footer: {
            Text(canReachICloud
                ? "Only needed when your devices keep showing different events. Each asks before it changes anything."
                : "These need iCloud. Sign in and check that Timity may use iCloud first.")
        }
        .disabled(!canReachICloud || running != nil)
    }

    private func repairButton(_ repair: Repair, systemImage: String) -> some View {
        Button(role: repair == .removeFromICloud ? .destructive : nil) {
            confirming = repair
        } label: {
            Label {
                Text(buttonTitle(repair))
            } icon: {
                if running == repair {
                    ProgressView()
                } else {
                    Image(systemName: systemImage)
                }
            }
        }
    }

    private func run(_ repair: Repair) {
        Task {
            running = repair
            repairResult = nil
            repairError = nil
            do {
                switch repair {
                case .downloadAgain: try await repairs.downloadAgain()
                case .uploadAgain: try await repairs.uploadAgain()
                case .removeFromICloud: try await repairs.removeFromICloud()
                }
                repairResult = doneMessage(repair)
            } catch {
                repairError = Self.describe(error)
            }
            running = nil
        }
    }

    private func buttonTitle(_ repair: Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Download Again from iCloud"
        case .uploadAgain: "Upload Again from This Device"
        case .removeFromICloud: "Remove from iCloud"
        }
    }

    private func confirmationTitle(_ repair: Repair) -> String {
        switch repair {
        case .downloadAgain: String(localized: "Replace This Device's Events with iCloud's?")
        case .uploadAgain: String(localized: "Replace iCloud's Events with This Device's?")
        case .removeFromICloud: String(localized: "Remove Your Events from iCloud?")
        }
    }

    private func confirmationMessage(_ repair: Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "The events on this device are removed and downloaded again from iCloud. Changes that haven't synced yet are lost."
        case .uploadAgain: "The events in iCloud are replaced with the ones on this device, and your other devices get them from there. Changes only your other devices have are lost."
        case .removeFromICloud: "Your events are deleted from iCloud and sync turns off. They stay on this device. On your other devices, Timity may remove the events it got from iCloud."
        }
    }

    private func actionTitle(_ repair: Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Download Again"
        case .uploadAgain: "Upload Again"
        case .removeFromICloud: "Remove from iCloud"
        }
    }

    private func doneMessage(_ repair: Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Done. Your events are downloading from iCloud; this can take a moment."
        case .uploadAgain: "Done. This device's events are uploading to iCloud."
        case .removeFromICloud: "Done. Your events are no longer in iCloud, and sync is off."
        }
    }

    /// The error and every error it wraps, each on a line of its own: Core Data
    /// keeps CloudKit's reason in the errors underneath its own.
    private static func describe(_ error: Error) -> String {
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
