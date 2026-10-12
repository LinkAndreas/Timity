import SwiftUI

/// The purchase options: placeholders while they load, a retry when they can't,
/// and one-time and recurring support once they're in, with the app icons
/// that recurring support unlocks.
struct SupportOffersSections: View {
    @Environment(SupportStore.self) private var store

    var body: some View {
        switch store.loadState {
        case .idle, .loading:
            // The same sections the offers will fill, as placeholders of the same
            // size — nothing jumps when the prices arrive, and nothing is tappable yet.
            SupportPlaceholderSection(oneTime: true, header: String(localized: "One-Time Support"), footer: String(localized: "A single payment. Nothing renews."))
            SupportPlaceholderSection(oneTime: false, header: String(localized: "Recurring Support"), footer: String(localized: "Recurring support unlocks the alternative app icons; every feature of Timity stays free. Payment is charged to your Apple Account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel them anytime in your Apple Account settings."))

        case .unavailable:
            Section {
                Text(String(localized: "Support options couldn't be loaded. Check your internet connection and try again."))
                    .foregroundStyle(.secondary)
                Button(String(localized: "Try Again")) {
                    Task { await store.load() }
                }
            }

        case .loaded:
            if !store.oneTimeOffers.isEmpty {
                Section {
                    ForEach(store.oneTimeOffers) { offer in
                        SupportPurchaseRow(offer: offer, isProminent: true)
                    }
                } header: {
                    Text(String(localized: "One-Time Support"))
                } footer: {
                    Text(String(localized: "A single payment. Nothing renews."))
                }
            }

            // What recurring support unlocks, just above it. Supporters have the
            // icons at the top of the screen instead.
            if !store.subscriptionOffers.isEmpty, !store.isSupporter {
                AppThemeSection(isUnlocked: false)
            }

            if !store.subscriptionOffers.isEmpty {
                Section {
                    ForEach(store.subscriptionOffers) { offer in
                        SupportPurchaseRow(offer: offer, isProminent: false)
                    }
                } header: {
                    Text(String(localized: "Recurring Support"))
                } footer: {
                    Text(String(localized: "Recurring support unlocks the alternative app icons; every feature of Timity stays free. Payment is charged to your Apple Account. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel them anytime in your Apple Account settings."))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    Form {
        SupportOffersSections()
    }
    .environment(SupportStore(service: PreviewSupportService()))
}
#endif
