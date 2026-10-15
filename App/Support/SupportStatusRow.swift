import SwiftUI

struct SupportStatusRow: View {
    let status: SupportStore.Status

    var body: some View {
        switch status {
        case .thankYou:
            Label(String(localized: "support.thankYouForYourSupport"), systemImage: "heart.fill")
                .foregroundStyle(.pink)
        case .pending:
            Label(String(localized: "support.yourPurchaseIsWaitingFor"), systemImage: "clock")
        case .restored:
            Label(String(localized: "support.purchasesRestored"), systemImage: "checkmark.circle")
        case .nothingToRestore:
            Label(String(localized: "support.thereWereNoPurchasesTo"), systemImage: "info.circle")
        case let .failed(error):
            Label(error.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}

nonisolated private extension SupportStoreError {
    var message: String {
        switch self {
        case .storeUnavailable:
            String(localized: "support.supportOptionsCouldntBeLoaded")
        case .productUnavailable, .purchaseFailed:
            String(localized: "support.thePurchaseCouldntBeCompleted")
        case .verificationFailed:
            String(localized: "support.thePurchaseCouldntBeVerified")
        case .restoreFailed:
            String(localized: "support.purchasesCouldntBeRestoredPlease")
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
