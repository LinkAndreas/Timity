import Foundation
import Synchronization
import WatchConnectivity

/// Tells the paired Apple Watch whether events sync, so it follows the setting.
protocol SyncSettingSharing {
    func share(syncsWithICloud: Bool)
}

/// Hands the setting to the Watch as the application context, which watchOS
/// keeps only the latest of and delivers when the Watch app next runs. It sends
/// again once the session is ready, the Watch app is installed or another Watch
/// is paired.
final class WatchConnectivitySyncSettingSharer: NSObject, SyncSettingSharing, WCSessionDelegate {
    private let latest = Mutex<Bool?>(nil)

    override init() {
        super.init()
        // iPads have no Watch.
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func share(syncsWithICloud: Bool) {
        latest.withLock { $0 = syncsWithICloud }
        send(over: .default)
    }

    private func send(over session: WCSession) {
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let value = latest.withLock({ $0 }) else { return }
        do {
            try session.updateApplicationContext([SyncSettingContext.key: value])
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

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user switched to another Watch; activating again reaches it.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
