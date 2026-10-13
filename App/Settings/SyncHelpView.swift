import SwiftUI
import UIKit

/// Ways out when this device and iCloud don't agree.
struct CloudSyncRepairs {
    /// Replaces this device's events with iCloud's.
    let downloadAgain: () async throws -> Void
    /// Replaces iCloud's events with this device's.
    let uploadAgain: () async throws -> Void
    /// Deletes the events from iCloud and turns sync off, keeping them here.
    let removeFromICloud: () async throws -> Void
}

/// What someone notices when sync goes wrong, each with the steps that help,
/// the safest first.
enum SyncSymptom: CaseIterable, Identifiable {
    case missingHere, notOnOtherDevices, duplicates, deletedComeBack, stopUsingICloud

    enum Step {
        case sameAccount, allowICloud, keepOpen, checkAgain, otherDevice, waitForMerge, deleteExtras, deleteAgain, turnOffSync
    }

    enum Repair {
        case downloadAgain, uploadAgain, removeFromICloud
    }

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .missingHere: "Events Are Missing Here"
        case .notOnOtherDevices: "Changes Don't Reach My Other Devices"
        case .duplicates: "I See Events Twice"
        case .deletedComeBack: "Deleted Events Come Back"
        case .stopUsingICloud: "I Want to Stop Using iCloud"
        }
    }

    var systemImage: String {
        switch self {
        case .missingHere: "icloud.and.arrow.down"
        case .notOnOtherDevices: "ipad.and.iphone"
        case .duplicates: "square.on.square"
        case .deletedComeBack: "arrow.uturn.backward.circle"
        case .stopUsingICloud: "icloud.slash"
        }
    }

    var steps: [Step] {
        switch self {
        case .missingHere: [.sameAccount, .allowICloud, .keepOpen, .checkAgain]
        case .notOnOtherDevices: [.otherDevice, .sameAccount, .keepOpen]
        case .duplicates: [.waitForMerge, .deleteExtras]
        case .deletedComeBack: [.otherDevice, .deleteAgain]
        case .stopUsingICloud: [.turnOffSync]
        }
    }

    /// The bigger fix, for when the steps didn't help.
    var repair: Repair {
        switch self {
        case .missingHere, .duplicates: .downloadAgain
        case .notOnOtherDevices, .deletedComeBack: .uploadAgain
        case .stopUsingICloud: .removeFromICloud
        }
    }
}

/// One problem, walked through: what to check first, then the fix that replaces
/// one side with the other, explained before it's used.
struct SyncProblemGuide: View {
    let symptom: SyncSymptom
    @Binding var syncsWithICloud: Bool
    let state: () -> CloudSyncState
    let checkAgain: () async -> Void
    let repairs: CloudSyncRepairs

    @Environment(\.openURL) private var openURL
    @State private var isChecking = false
    @State private var isConfirming = false
    @State private var isRunning = false
    @State private var result: LocalizedStringResource?
    @State private var error: String?

    var body: some View {
        let state = state()

        Form {
            Section {
                CloudSyncStatusLabel(state: state)
            }

            Section("Try These First") {
                ForEach(Array(symptom.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(step, number: index + 1)
                }
            }

            Section {
                Text(explanation(symptom.repair))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(role: symptom.repair == .removeFromICloud ? .destructive : nil) {
                    isConfirming = true
                } label: {
                    Label {
                        Text(buttonTitle(symptom.repair))
                    } icon: {
                        if isRunning {
                            ProgressView()
                        } else {
                            Image(systemName: symbol(symptom.repair))
                        }
                    }
                }
                .disabled(isRunning || state.account != .available)
                if let result {
                    Label { Text(result) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        .font(.subheadline)
                }
                if let error {
                    Text(verbatim: error)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Still Not Fixed?")
            } footer: {
                if state.account != .available {
                    Text("This needs iCloud. Sign in and check that Timity may use iCloud first.")
                } else {
                    Text("Your events on this device are kept safe while this runs.")
                }
            }
        }
        .navigationTitle(Text(symptom.title))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Text(confirmationTitle(symptom.repair)), isPresented: $isConfirming, titleVisibility: .visible) {
            Button(role: .destructive, action: run) { Text(actionTitle(symptom.repair)) }
        } message: {
            Text(confirmationMessage(symptom.repair))
        }
    }

    // MARK: Steps

    @ViewBuilder
    private func stepRow(_ step: SyncSymptom.Step, number: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(number, format: .number)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: .circle)
            VStack(alignment: .leading, spacing: 8) {
                Text(text(step))
                stepAction(step)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func stepAction(_ step: SyncSymptom.Step) -> some View {
        switch step {
        case .allowICloud:
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .checkAgain:
            Button {
                Task {
                    isChecking = true
                    async let minimum: Void = (try? await Task.sleep(for: .milliseconds(800))) ?? ()
                    await checkAgain()
                    await minimum
                    isChecking = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isChecking { ProgressView().controlSize(.small) }
                    Text(isChecking ? LocalizedStringKey("Checking iCloud…") : LocalizedStringKey("Check Again"))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isChecking)
        case .turnOffSync:
            Toggle("Sync with iCloud", isOn: $syncsWithICloud)
        default:
            EmptyView()
        }
    }

    private func text(_ step: SyncSymptom.Step) -> LocalizedStringResource {
        switch step {
        case .sameAccount: "Make sure all your devices use the same Apple Account."
        case .allowICloud: "In Settings, tap your name, then iCloud, and check that Timity may use iCloud."
        case .keepOpen: "Connect to Wi‑Fi, turn off Low Power Mode, and keep Timity open for a minute."
        case .checkAgain: "Then check whether iCloud can be reached."
        case .otherDevice: "On your other device, update Timity, open it, and check that Sync with iCloud is on."
        case .waitForMerge: "Wait a minute: copies of the same event made on two devices merge once both have synced."
        case .deleteExtras: "Delete any that remain: in Events, tap Sort and Filter, then Select Events."
        case .deleteAgain: "Once all your devices have synced, delete the events again."
        case .turnOffSync: "Turn off Sync with iCloud. Your events stay on this device, and iCloud keeps its copy."
        }
    }

    // MARK: Repair

    private func run() {
        Task {
            isRunning = true
            result = nil
            error = nil
            do {
                switch symptom.repair {
                case .downloadAgain: try await repairs.downloadAgain()
                case .uploadAgain: try await repairs.uploadAgain()
                case .removeFromICloud: try await repairs.removeFromICloud()
                }
                result = doneMessage(symptom.repair)
            } catch {
                self.error = CloudSyncView.describe(error)
            }
            isRunning = false
        }
    }

    private func explanation(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Replace the events on this device with the ones in iCloud. Use this when iCloud has the right events."
        case .uploadAgain: "Replace the events in iCloud with the ones on this device. Use this when this device has the right events; your other devices then follow."
        case .removeFromICloud: "Delete your events from iCloud for good and stop syncing. They stay on this device."
        }
    }

    private func symbol(_ repair: SyncSymptom.Repair) -> String {
        switch repair {
        case .downloadAgain: "icloud.and.arrow.down"
        case .uploadAgain: "icloud.and.arrow.up"
        case .removeFromICloud: "xmark.icloud"
        }
    }

    private func buttonTitle(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Download Again from iCloud"
        case .uploadAgain: "Upload Again from This Device"
        case .removeFromICloud: "Remove from iCloud"
        }
    }

    private func confirmationTitle(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Replace This Device's Events with iCloud's?"
        case .uploadAgain: "Replace iCloud's Events with This Device's?"
        case .removeFromICloud: "Remove Your Events from iCloud?"
        }
    }

    private func confirmationMessage(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "The events on this device are removed and downloaded again from iCloud. Changes that haven't synced yet are lost."
        case .uploadAgain: "The events in iCloud are replaced with the ones on this device, and your other devices get them from there. Changes only your other devices have are lost."
        case .removeFromICloud: "Your events are deleted from iCloud and sync turns off. They stay on this device. On your other devices, Timity may remove the events it got from iCloud."
        }
    }

    private func actionTitle(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Download Again"
        case .uploadAgain: "Upload Again"
        case .removeFromICloud: "Remove from iCloud"
        }
    }

    private func doneMessage(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "Done. Your events are downloading from iCloud; this can take a moment."
        case .uploadAgain: "Done. This device's events are uploading to iCloud."
        case .removeFromICloud: "Done. Your events are no longer in iCloud, and sync is off."
        }
    }
}

/// A support email with what's needed to help: how sync is doing and on what.
/// No events or personal details go in it.
enum SyncReport {
    static func mailURL(state: CloudSyncState, to address: String) -> URL? {
        var lines = [
            "",
            "",
            "———",
            "Timity \(Bundle.main.versionDescription) · \(UIDevice.current.systemName) \(UIDevice.current.systemVersion) · \(UIDevice.current.model)",
            "Sync: \(state.isEnabled ? "on" : "off") · Store syncs: \(state.storeSyncs) · Account: \(state.account)",
            "Last synced: \(state.lastSynced?.formatted(.iso8601) ?? "never")",
        ]
        if let problem = state.problem { lines.append("Problem: \(problem)") }
        if let details = state.problemDetails { lines.append("Details: \(details)") }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Timity iCloud Sync"),
            URLQueryItem(name: "body", value: lines.joined(separator: "\n")),
        ]
        return components.url
    }
}
