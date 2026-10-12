import CloudKit

/// Whether events can sync through iCloud.
enum CloudAccountStatus {
    case available
    case noAccount
    case unavailable
}

enum CloudKitAccount {
    static func status(container identifier: String) async -> CloudAccountStatus {
        switch try? await CKContainer(identifier: identifier).accountStatus() {
        case .available: .available
        case .noAccount: .noAccount
        default: .unavailable
        }
    }
}
