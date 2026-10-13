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
        /// The store couldn't be set up for iCloud and opened on this device only.
        case couldNotStart
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
        case other
    }

    /// One step of syncing: setting up, downloading or uploading.
    struct Activity: Equatable {
        let id: UUID
        /// When it finished; `nil` while it runs.
        var endDate: Date?
        var succeeded = false
        /// Why it failed; `nil` when sync retries by itself, as after a conflict.
        var problem: Problem?
        /// The technical error behind the problem, for feedback.
        var details: String?
    }

    /// Whether the user wants events synced.
    var isEnabled: Bool
    var account = Account.unknown
    var lastSynced: Date?
    /// Why the last step failed; cleared by the next one that succeeds.
    var lastFailure: Problem?
    /// The technical error behind the last failure.
    var lastFailureDetails: String?
    /// Whether the store opened with iCloud; it falls back to this device alone
    /// when it can't.
    var storeSyncs = true
    private var running: Set<UUID> = []

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    var isSyncing: Bool {
        isEnabled && !running.isEmpty
    }

    /// What keeps events from syncing, the account first.
    /// The technical error behind the current problem, when a failed sync caused it.
    var problemDetails: String? {
        problem != nil && problem == lastFailure ? lastFailureDetails : nil
    }

    var problem: Problem? {
        guard isEnabled else { return nil }
        guard storeSyncs else { return .couldNotStart }
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
            lastFailureDetails = nil
        } else if let problem = activity.problem {
            lastFailure = problem
            lastFailureDetails = activity.details
        }
    }

    /// Starts over when sync is turned on or off.
    mutating func setEnabled(_ isOn: Bool) {
        isEnabled = isOn
        running = []
        lastFailure = nil
    }
}

/// How the iPhone tells the Apple Watch whether events sync: the Watch has no
/// setting of its own and follows the iPhone's.
enum SyncSettingContext {
    static let key = "syncsWithICloud"
}

/// Follows iCloud sync of the event store and the iCloud account.
@MainActor
@Observable
final class CloudKitSyncMonitor {
    private(set) var state: CloudSyncState

    @ObservationIgnored private let containerIdentifier: String
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(isEnabled: Bool, storeSyncs: Bool, containerIdentifier: String) {
        var state = CloudSyncState(isEnabled: isEnabled)
        state.storeSyncs = storeSyncs
        self.state = state
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

    /// - Parameter storeSyncs: Whether the store reopened with iCloud.
    func setEnabled(_ isOn: Bool, storeSyncs: Bool) {
        state.setEnabled(isOn)
        state.storeSyncs = storeSyncs
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
        let cause = event.error.flatMap(Self.cause)
        state.record(CloudSyncState.Activity(
            id: event.identifier,
            endDate: event.endDate,
            succeeded: event.succeeded,
            problem: cause?.problem,
            details: cause.map { Self.describe($0.error) }
        ))
    }

    /// "CKErrorDomain 12: Invalid Arguments — <the server's own explanation>".
    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        var text = "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
        if let server = nsError.userInfo["ServerErrorDescription"] as? String, !server.isEmpty {
            text += " — \(server)"
        }
        return text
    }

    /// The reason behind a failed step and the error that gives it, looking
    /// through the errors CloudKit and Core Data wrap it in; `nil` for failures
    /// sync recovers from by itself.
    private static func cause(_ error: Error) -> (problem: CloudSyncState.Problem, error: Error)? {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated: return (.noAccount, error)
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy: return (.offline, error)
            case .quotaExceeded: return (.storageFull, error)
            case .serverRejectedRequest, .invalidArguments, .incompatibleVersion: return (.rejected, error)
            // A batch fails as a whole: one record has the reason, the others only
            // "Atomic failure". Conflicts, oversized batches and missing zones are
            // resolved by the next attempt.
            case .batchRequestFailed, .serverRecordChanged, .limitExceeded, .zoneNotFound, .operationCancelled:
                return nil
            case .partialFailure:
                return (ckError.partialErrorsByItemID ?? [:]).values.lazy.compactMap(cause).first
            default: break
            }
        }
        if let underlying = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error {
            return cause(underlying)
        }
        return (.other, error)
    }
}
