import Foundation
import Synchronization
import WatchConnectivity

/// Whether events sync, as Timity on the iPhone does: the Watch has no setting of
/// its own. Until the iPhone has said so — or while its welcome hasn't asked yet —
/// events stay on this Watch, so it never syncs when the iPhone doesn't.
nonisolated final class PhoneSyncSetting: NSObject, WCSessionDelegate, Sendable {
    nonisolated enum State: Equatable, Sendable {
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

    // UserDefaults is thread-safe; it just isn't marked Sendable.
    nonisolated(unsafe) private let defaults: UserDefaults
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

    /// Listens to the iPhone and reports the state once the latest word from it is
    /// in — right after activation, changed or not — and whenever it changes.
    func start(onChange: @escaping @Sendable @MainActor (State) -> Void) {
        self.onChange.withLock { $0 = onChange }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Takes in what the iPhone sent; reports the state when it changed, or always
    /// when `reportsUnchanged`, which confirms the state the app started with.
    private func receive(_ context: [String: Any], reportsUnchanged: Bool = false) {
        let before = state
        if let syncs = context[SyncSettingContext.key] as? Bool {
            defaults.set(syncs, forKey: SyncSettingContext.key)
            defaults.set(context[SyncSettingContext.isSetUpKey] as? Bool ?? true, forKey: SyncSettingContext.isSetUpKey)
        }
        let after = state
        guard after != before || reportsUnchanged, let onChange = onChange.withLock({ $0 }) else { return }
        Task { @MainActor in onChange(after) }
    }

    /// While watchOS has woken the app in the background to hand over something
    /// from the iPhone, keeps it awake until that's done and the store has had a
    /// moment to switch — so turning sync off on the iPhone takes effect here
    /// without opening Timity.
    static func receivePendingContent() async {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let deadline = Date.now.addingTimeInterval(10)
        while Date.now < deadline, session.activationState != .activated || session.hasContentPending {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(500))
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
        if let error { logger.error("WatchConnectivity didn't activate: \(error)") }
        receive(session.receivedApplicationContext, reportsUnchanged: true)
        askPhone(over: session)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        askPhone(over: session)
    }
}
