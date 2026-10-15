import Foundation
import Synchronization
import WatchConnectivity

/// Tells the paired Apple Watch whether events sync, so it follows the iPhone.
nonisolated protocol SyncSettingSharing {
    /// - Parameters:
    ///   - syncsWithICloud: Whether this iPhone syncs events now.
    ///   - isSetUp: Whether the welcome, which asks about iCloud, is done.
    func share(syncsWithICloud: Bool, isSetUp: Bool)
}

/// Hands the setting to the Watch as the application context, which watchOS
/// keeps only the latest of and delivers when the Watch app next runs. It sends
/// again once the session is ready, the Watch app is installed or another Watch
/// is paired, and answers a Watch that asks before it has heard anything.
nonisolated final class WatchConnectivitySyncSettingSharer: NSObject, SyncSettingSharing, WCSessionDelegate, Sendable {
    private let latest = Mutex<[String: Any]?>(nil)

    override init() {
        super.init()
        // iPads have no Watch.
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func share(syncsWithICloud: Bool, isSetUp: Bool) {
        latest.withLock { $0 = SyncSettingContext.context(syncsWithICloud: syncsWithICloud, isSetUp: isSetUp) }
        send(over: .default)
    }

    private func send(over session: WCSession) {
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let context = latest.withLock({ $0 }) else { return }
        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Couldn't tell the Watch about iCloud sync: \(error)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        send(over: session)
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        send(over: session)
    }

    /// A Watch that has heard nothing yet asks; watchOS wakes this app to answer.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[SyncSettingContext.requestKey] != nil else { return replyHandler([:]) }
        replyHandler(latest.withLock { $0 } ?? [:])
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user switched to another Watch; activating again reaches it.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
