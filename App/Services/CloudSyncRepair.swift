import CloudKit
import Foundation

/// Deletes Timity's events from the user's private iCloud database.
protocol CloudEventsRemoving: Sendable {
    func removeEventsFromICloud() async throws
}

/// The zone Core Data mirrors the events into; deleting it deletes them all.
struct CloudKitEventsRemover: CloudEventsRemoving {
    let containerIdentifier: String

    func removeEventsFromICloud() async throws {
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await CKContainer(identifier: containerIdentifier).privateCloudDatabase.deleteRecordZone(withID: zone)
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .userDeletedZone {
            // Nothing in iCloud to remove.
        }
    }
}

/// Ways out when this device and iCloud don't agree: download everything again,
/// upload this device's events again, or take them out of iCloud.
///
/// Whenever the store on this device is rebuilt, its events are written to a file
/// first and saved back afterwards; should Timity quit halfway, the next launch
/// saves them from the file.
@MainActor
final class CloudSyncRepair {
    private let database: EventDatabase
    private let repository: SwiftDataEventRepository
    private let remover: any CloudEventsRemoving
    private let pendingEventsURL: URL

    init(database: EventDatabase, repository: SwiftDataEventRepository, remover: any CloudEventsRemoving, pendingEventsURL: URL) {
        self.database = database
        self.repository = repository
        self.remover = remover
        self.pendingEventsURL = pendingEventsURL
    }

    /// Replaces the events on this device with those in iCloud. Changes that
    /// haven't been uploaded yet are lost.
    func downloadAgain() throws {
        try database.eraseAndReopen(syncsWithICloud: true)
        repository.reload()
    }

    /// Replaces the events in iCloud with those on this device.
    func uploadAgain() async throws {
        try await rebuild(removingFromICloud: true, syncsWithICloud: true)
    }

    /// Deletes the events from iCloud and keeps them on this device, which stops
    /// syncing.
    func removeFromICloud() async throws {
        try await rebuild(removingFromICloud: true, syncsWithICloud: false)
    }

    /// Saves events kept for a rebuild that didn't finish.
    func restorePendingEvents() {
        guard let data = try? Data(contentsOf: pendingEventsURL) else { return }
        if let events = try? JSONDecoder().decode([EventSnapshot].self, from: data) {
            repository.save(events)
            logger.info("Restored \(events.count) events from an unfinished rebuild")
        }
        try? FileManager.default.removeItem(at: pendingEventsURL)
    }

    private func rebuild(removingFromICloud: Bool, syncsWithICloud: Bool) async throws {
        let events = repository.events
        try JSONEncoder().encode(events).write(to: pendingEventsURL, options: .atomic)
        // Stop syncing first, so iCloud's deletion can't reach this device's events.
        database.reopen(syncsWithICloud: false)
        if removingFromICloud {
            do {
                try await remover.removeEventsFromICloud()
            } catch {
                // Nothing has changed yet; carry on syncing as before.
                database.reopen(syncsWithICloud: true)
                try? FileManager.default.removeItem(at: pendingEventsURL)
                throw error
            }
        }
        do {
            try database.eraseAndReopen(syncsWithICloud: syncsWithICloud)
        } catch {
            // The old store may still be there; saving below brings back what's missing.
            logger.error("Couldn't erase the event store: \(error)")
            database.reopen(syncsWithICloud: syncsWithICloud)
        }
        repository.save(events)
        repository.reload()
        try? FileManager.default.removeItem(at: pendingEventsURL)
    }
}
