import SwiftUI

/// One line on how sync is doing.
struct CloudSyncStatusLabel: View {
    let state: CloudSyncState
    /// Whether a problem shows in its own colour; off where the status is only a quiet note.
    var colorsProblems = true

    var body: some View {
        Label {
            state.statusText
        } icon: {
            Image(systemName: state.statusSymbol)
                .symbolEffect(.pulse, isActive: state.isSyncing)
        }
        .modifier(StatusTint(tint: colorsProblems ? state.statusTint : nil))
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

nonisolated extension CloudSyncState {
    var statusText: Text {
        if !isEnabled, awaitsPhone { return Text("sync.waitingForTimityOnIPhone") }
        if !isEnabled { return Text("sync.offEventsStayOnThis") }
        if isSyncing { return Text("sync.syncing") }
        if let problem { return Text(problem.title) }
        if let lastSynced { return Self.lastSyncedText(lastSynced) }
        if account == .available { return Text("sync.syncingWithICloud") }
        return Text("sync.checkingICloud")
    }

    /// "Up to date" in the first minute, then "Last synced 5 minutes ago": "Synced now" reads
    /// like no one would say it, in any language.
    static func lastSyncedText(_ date: Date, now: Date = .now) -> Text {
        if now.timeIntervalSince(date) < 60 { return Text("sync.upToDate") }
        return Text("sync.synced \(date, format: .relative(presentation: .named))")
    }

    var statusSymbol: String {
        if !isEnabled, awaitsPhone { return "iphone" }
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

nonisolated extension CloudSyncState.Problem {
    var title: LocalizedStringResource {
        switch self {
        case .couldNotStart: "sync.icloudSyncCouldntStart"
        case .noAccount: "sync.notSignedInToICloud"
        case .restricted: "sync.icloudIsRestricted"
        case .unavailable: "sync.icloudIsntAvailable"
        case .offline: "sync.waitingForAConnection"
        case .storageFull: "sync.icloudStorageIsFull"
        case .rejected: "sync.cantSyncWithICloudRight"
        case .other: "sync.syncPaused"
        }
    }

    var advice: LocalizedStringResource {
        switch self {
        case .couldNotStart: "sync.yourEventsAreSafeOn"
        #if os(watchOS)
        case .noAccount: "sync.signInToICloudOn"
        #elseif os(macOS)
        case .noAccount: "sync.signInWithYourApple.mac"
        #else
        case .noAccount: "sync.signInWithYourApple"
        #endif
        case .restricted: "sync.screenTimeOrADevice"
        #if os(watchOS)
        case .unavailable: "sync.onYourIPhoneOpenSettings"
        #elseif os(macOS)
        case .unavailable: "sync.inSettingsTapYourName.mac"
        #else
        case .unavailable: "sync.inSettingsTapYourName"
        #endif
        case .offline: "sync.yourEventsSyncOnceThis"
        case .storageFull: "sync.freeUpSpaceOrAdd"
        case .rejected: "sync.yourEventsAreSafeOn2"
        case .other: "sync.timityTriesAgainShortlyIf"
        }
    }

    var isFixedInSettings: Bool {
        switch self {
        case .noAccount, .unavailable, .storageFull: true
        default: false
        }
    }
}
