import StoreKit

/// Whether this copy of Timity comes from Xcode or TestFlight rather than the App
/// Store, for settings that only testers see.
enum TestBuild {
    static var isRunning: Bool {
        get async {
            #if DEBUG
            return true
            #else
            guard case .verified(let transaction)? = try? await AppTransaction.shared else { return false }
            return transaction.environment == .sandbox || transaction.environment == .xcode
            #endif
        }
    }
}
