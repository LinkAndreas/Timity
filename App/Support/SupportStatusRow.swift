import SwiftUI

struct SupportStatusRow: View {
    let status: SupportStore.Status

    var body: some View {
        switch status {
        case .thankYou:
            Label(String(localized: "Thank you for your support"), systemImage: "heart.fill")
                .foregroundStyle(.pink)
        case .pending:
            Label(String(localized: "Your purchase is waiting for approval. It will complete automatically once approved."), systemImage: "clock")
        case .restored:
            Label(String(localized: "Purchases restored."), systemImage: "checkmark.circle")
        case .nothingToRestore:
            Label(String(localized: "There were no purchases to restore."), systemImage: "info.circle")
        case let .failed(error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

private extension SupportStoreError {
    var message: String {
        switch self {
        case .storeUnavailable:
            String(localized: "Support options couldn't be loaded. Check your internet connection and try again.")
        case .productUnavailable, .purchaseFailed:
            String(localized: "The purchase couldn't be completed. Please try again.")
        case .verificationFailed:
            String(localized: "The purchase couldn't be verified by the App Store.")
        case .restoreFailed:
            String(localized: "Purchases couldn't be restored. Please try again.")
        }
    }
}

#if DEBUG
#Preview {
    List {
        SupportStatusRow(status: .thankYou)
        SupportStatusRow(status: .pending)
        SupportStatusRow(status: .failed(.storeUnavailable))
    }
}
#endif
