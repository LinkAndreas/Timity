import Foundation
import Synchronization
import WatchConnectivity

/// Whether events sync, as set in Timity on the iPhone: the Watch has no setting
/// of its own. It's on until the iPhone says otherwise.
final class PhoneSyncSetting: NSObject, WCSessionDelegate {
    private let defaults: UserDefaults
    private let onChange = Mutex<(@Sendable @MainActor (Bool) -> Void)?>(nil)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var syncsWithICloud: Bool {
        defaults.object(forKey: SyncSettingContext.key) == nil || defaults.bool(forKey: SyncSettingContext.key)
    }

    /// Listens to the iPhone and reports when the setting changes.
    func start(onChange: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onChange.withLock { $0 = onChange }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func receive(_ context: [String: Any]) {
        guard let value = context[SyncSettingContext.key] as? Bool, value != syncsWithICloud else { return }
        defaults.set(value, forKey: SyncSettingContext.key)
        guard let onChange = onChange.withLock({ $0 }) else { return }
        Task { @MainActor in onChange(value) }
    }

    // The context last sent arrives with activation, should it have come while
    // the app wasn't running.
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
}
