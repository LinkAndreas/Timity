import SwiftUI

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
        case .missingHere: "sync.eventsAreMissingHere"
        case .notOnOtherDevices: "sync.changesDontReachMyOther"
        case .duplicates: "sync.iSeeEventsTwice"
        case .deletedComeBack: "sync.deletedEventsComeBack"
        case .stopUsingICloud: "sync.iWantToStopUsing"
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

            Section("sync.tryTheseFirst") {
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
                Text("sync.stillNotFixed")
            } footer: {
                if state.account != .available {
                    Text("sync.thisNeedsICloudSignIn")
                } else {
                    Text("sync.yourEventsOnThisDevice")
                }
            }
        }
        .navigationTitle(Text(symptom.title))
        .inlineNavigationTitle()
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
            Button("common.openSettings") {
                if let url = Platform.appSettingsURL { openURL(url) }
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
                    Text(isChecking ? LocalizedStringKey("sync.checkingICloud") : LocalizedStringKey("sync.checkAgain"))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isChecking)
        case .turnOffSync:
            Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
        default:
            EmptyView()
        }
    }

    private func text(_ step: SyncSymptom.Step) -> LocalizedStringResource {
        switch step {
        case .sameAccount: "sync.makeSureAllYourDevices"
        #if os(macOS)
        case .allowICloud: "sync.inSettingsTapYourName.mac"
        #else
        case .allowICloud: "sync.inSettingsTapYourName"
        #endif
        case .keepOpen: "sync.connectToWiFiTurn"
        case .checkAgain: "sync.thenCheckWhetherICloudCan"
        case .otherDevice: "sync.onYourOtherDeviceUpdate"
        case .waitForMerge: "sync.waitAMinuteCopiesOf"
        #if os(macOS)
        case .deleteExtras: "sync.deleteAnyThatRemainIn.mac"
        #else
        case .deleteExtras: "sync.deleteAnyThatRemainIn"
        #endif
        case .deleteAgain: "sync.onceAllYourDevicesHave"
        case .turnOffSync: "sync.turnOffSyncWithICloud"
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
        case .downloadAgain: "sync.replaceTheEventsOnThis"
        case .uploadAgain: "sync.replaceTheEventsInICloud"
        case .removeFromICloud: "sync.deleteYourEventsFromICloud"
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
        case .downloadAgain: "sync.downloadAgainFromICloud"
        case .uploadAgain: "sync.uploadAgainFromThisDevice"
        case .removeFromICloud: "sync.removeFromICloud"
        }
    }

    private func confirmationTitle(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "sync.replaceThisDevicesEventsWith"
        case .uploadAgain: "sync.replaceICloudsEventsWithThis"
        case .removeFromICloud: "sync.removeYourEventsFromICloud"
        }
    }

    private func confirmationMessage(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "sync.theEventsOnThisDevice"
        case .uploadAgain: "sync.theEventsInICloudAre"
        case .removeFromICloud: "sync.yourEventsAreDeletedFrom"
        }
    }

    private func actionTitle(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "sync.downloadAgain"
        case .uploadAgain: "sync.uploadAgain"
        case .removeFromICloud: "sync.removeFromICloud"
        }
    }

    private func doneMessage(_ repair: SyncSymptom.Repair) -> LocalizedStringResource {
        switch repair {
        case .downloadAgain: "sync.doneYourEventsAreDownloading"
        case .uploadAgain: "sync.doneThisDevicesEventsAre"
        case .removeFromICloud: "sync.doneYourEventsAreNo"
        }
    }
}

/// A support email with what's needed to help: how sync is doing and on what.
/// No events or personal details go in it.
enum SyncReport {
    static func mailURL(state: CloudSyncState) -> URL? {
        var details = [
            "Sync: \(state.isEnabled ? "on" : "off") · Store syncs: \(state.storeSyncs) · Account: \(state.account)",
            "Last synced: \(state.lastSynced?.formatted(.iso8601) ?? "never")",
        ]
        if let problem = state.problem { details.append("Problem: \(problem)") }
        if let problemDetails = state.problemDetails { details.append("Details: \(problemDetails)") }
        return SupportMail.url(subject: "Timity iCloud Sync", details: details)
    }
}
