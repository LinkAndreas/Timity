import CloudKit
import CoreData
import Foundation
import Observation

/// How iCloud sync is doing, for the status the app shows of it.
struct CloudSyncState: Equatable {
    enum Account: Equatable {
        case unknown, available, noAccount, restricted, unavailable
    }

    /// Why events aren't syncing.
    enum Problem: Equatable {
        case noAccount
        /// Parental controls or a device profile keep Timity from iCloud.
        case restricted
        /// iCloud can't be reached right now, or Timity isn't allowed to use it.
        case unavailable
        case offline
        case storageFull
        /// iCloud turned the events down, usually because it doesn't know a newer
        /// field yet.
        case rejected
        case other(String)
    }

    /// One step of syncing: setting up, downloading or uploading.
    struct Activity: Equatable {
        let id: UUID
        /// When it finished; `nil` while it runs.
        var endDate: Date?
        var succeeded = false
        var problem: Problem?
    }

    /// Whether the user wants events synced.
    var isEnabled: Bool
    var account = Account.unknown
    var lastSynced: Date?
    /// Why the last step failed; cleared by the next one that succeeds.
    var lastFailure: Problem?
    private var running: Set<UUID> = []

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    var isSyncing: Bool {
        isEnabled && !running.isEmpty
    }

    /// What keeps events from syncing, the account first.
    var problem: Problem? {
        guard isEnabled else { return nil }
        switch account {
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .unavailable: return .unavailable
        case .unknown, .available: return lastFailure
        }
    }

    mutating func record(_ activity: Activity) {
        guard activity.endDate != nil else {
            running.insert(activity.id)
            return
        }
        running.remove(activity.id)
        if activity.succeeded {
            lastSynced = activity.endDate
            lastFailure = nil
        } else {
            lastFailure = activity.problem ?? .other("")
        }
    }

    /// Starts over when sync is turned on or off.
    mutating func setEnabled(_ isOn: Bool) {
        isEnabled = isOn
        running = []
        lastFailure = nil
    }
}

/// Follows iCloud sync of the event store and the iCloud account.
@MainActor
@Observable
final class CloudKitSyncMonitor {
    private(set) var state: CloudSyncState

    @ObservationIgnored private let containerIdentifier: String
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(isEnabled: Bool, containerIdentifier: String) {
        state = CloudSyncState(isEnabled: isEnabled)
        self.containerIdentifier = containerIdentifier
    }

    func start() {
        guard tasks.isEmpty else { return }
        tasks = [
            Task { [weak self] in
                for await notification in NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
                    guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { continue }
                    self?.record(event)
                }
            },
            Task { [weak self] in
                await self?.checkAccount()
                for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                    await self?.checkAccount()
                }
            },
        ]
    }

    func setEnabled(_ isOn: Bool) {
        state.setEnabled(isOn)
        Task { await checkAccount() }
    }

    func checkAccount() async {
        let status = try? await CKContainer(identifier: containerIdentifier).accountStatus()
        state.account = switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .temporarilyUnavailable, .couldNotDetermine: .unavailable
        case nil: .unavailable
        @unknown default: .unknown
        }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        if let error = event.error {
            logger.error("iCloud sync failed: \(error)")
        }
        state.record(CloudSyncState.Activity(
            id: event.identifier,
            endDate: event.endDate,
            succeeded: event.succeeded,
            problem: event.error.map(Self.problem)
        ))
    }

    /// The reason behind a failed step, looking through the errors CloudKit and
    /// Core Data wrap it in.
    private static func problem(_ error: Error) -> CloudSyncState.Problem {
        let nsError = error as NSError
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated: return .noAccount
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy: return .offline
            case .quotaExceeded: return .storageFull
            case .serverRejectedRequest, .invalidArguments, .incompatibleVersion: return .rejected
            case .partialFailure:
                if let first = ckError.partialErrorsByItemID?.values.first { return problem(first) }
            default: break
            }
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return problem(underlying)
        }
        return .other(error.localizedDescription)
    }
}
