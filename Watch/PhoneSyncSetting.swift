import Foundation
import Synchronization
import WatchConnectivity

/// Whether events sync, as Timity on the iPhone does: the Watch has no setting of
/// its own. Until the iPhone has said so — or while its welcome hasn't asked yet —
/// events stay on this Watch, so it never syncs when the iPhone doesn't.
final class PhoneSyncSetting: NSObject, WCSessionDelegate {
    enum State: Equatable, Sendable {
        /// Nothing heard from the iPhone yet.
        case unknown
        /// Timity on the iPhone hasn't finished its welcome, which asks about iCloud.
        case awaitingSetup
        case on
        case off

        /// Whether events sync now; waiting means they don't.
        var syncsWithICloud: Bool { self == .on }

        /// Whether sync waits for the iPhone.
        var awaitsPhone: Bool { self == .unknown || self == .awaitingSetup }
    }

    private let defaults: UserDefaults
    private let onChange = Mutex<(@Sendable @MainActor (State) -> Void)?>(nil)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var state: State {
        guard let syncs = defaults.object(forKey: SyncSettingContext.key) as? Bool else { return .unknown }
        // From an iPhone app before the welcome was reported, the setting alone.
        let isSetUp = defaults.object(forKey: SyncSettingContext.isSetUpKey) as? Bool ?? true
        if syncs { return .on }
        return isSetUp ? .off : .awaitingSetup
    }

    var syncsWithICloud: Bool { state.syncsWithICloud }

    /// Listens to the iPhone and reports when the state changes.
    func start(onChange: @escaping @Sendable @MainActor (State) -> Void) {
        self.onChange.withLock { $0 = onChange }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func receive(_ context: [String: Any]) {
        guard let syncs = context[SyncSettingContext.key] as? Bool else { return }
        let before = state
        defaults.set(syncs, forKey: SyncSettingContext.key)
        defaults.set(context[SyncSettingContext.isSetUpKey] as? Bool ?? true, forKey: SyncSettingContext.isSetUpKey)
        let after = state
        guard after != before, let onChange = onChange.withLock({ $0 }) else { return }
        Task { @MainActor in onChange(after) }
    }

    /// Without word from the iPhone, asks it directly; watchOS wakes Timity there
    /// to answer when the iPhone is in reach.
    private func askPhone(over session: WCSession) {
        guard state == .unknown, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SyncSettingContext.requestKey: true], replyHandler: { [weak self] reply in
            self?.receive(reply)
        }, errorHandler: { error in
            logger.info("Couldn't ask the iPhone about iCloud sync: \(error)")
        })
    }

    // The context last sent arrives with activation, should it have come while
    // the app wasn't running.
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
        askPhone(over: session)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        askPhone(over: session)
    }
}
