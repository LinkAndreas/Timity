import SwiftUI

/// The purchase options: placeholders while they load, a retry when they can't,
/// and one-time and recurring support once they're in, with the app icons
/// that recurring support unlocks.
struct SupportOffersSections<AppIcons: View>: View {
    let store: SupportStore
    /// The locked app icons recurring support unlocks.
    let lockedAppIcons: AppIcons
    /// Opens the system's subscription management, offered to subscribers.
    let manageSubscription: () -> Void

    var body: some View {
        switch store.loadState {
        case .idle, .loading:
            // The same sections the offers will fill, as placeholders of the same
            // size — nothing jumps when the prices arrive, and nothing is tappable yet.
            SupportPlaceholderSection(oneTime: true, header: String(localized: "support.oneTimeSupport"), footer: String(localized: "support.aSinglePaymentNothingRenews"))
            SupportPlaceholderSection(oneTime: false, header: String(localized: "support.recurringSupport"), footer: String(localized: "support.recurringSupportUnlocksTheAlternative"))

        case .unavailable:
            Section {
                Text(String(localized: "support.supportOptionsCouldntBeLoaded"))
                    .foregroundStyle(.secondary)
                Button(String(localized: "common.tryAgain")) {
                    Task { await store.load() }
                }
                .rowButtonStyle()
                // Subscribers can still manage theirs without the offers.
                ManageSubscriptionButton(isSubscribed: store.activeSubscription != nil, action: manageSubscription)
            }

        case .loaded:
            if !store.oneTimeOffers.isEmpty {
                Section {
                    ForEach(store.oneTimeOffers) { offer in
                        SupportPurchaseRow(offer: offer, isProminent: true, store: store)
                    }
                } header: {
                    Text(String(localized: "support.oneTimeSupport"))
                } footer: {
                    Text(String(localized: "support.aSinglePaymentNothingRenews"))
                }
            }

            // What recurring support unlocks, just above it. Supporters have the
            // icons at the top of the screen instead.
            if !store.subscriptionOffers.isEmpty, !store.isSupporter {
                lockedAppIcons
            }

            if !store.subscriptionOffers.isEmpty {
                Section {
                    ForEach(store.subscriptionOffers) { offer in
                        SupportPurchaseRow(offer: offer, isProminent: false, store: store)
                    }
                    ManageSubscriptionButton(isSubscribed: store.activeSubscription != nil, action: manageSubscription)
                } header: {
                    Text(String(localized: "support.recurringSupport"))
                } footer: {
                    Text(String(localized: "support.recurringSupportUnlocksTheAlternative"))
                }
            }
        }
    }
}

/// Manage Subscription, for subscribers only.
private struct ManageSubscriptionButton: View {
    let isSubscribed: Bool
    let action: () -> Void

    var body: some View {
        if isSubscribed {
            Button(String(localized: "support.manageSubscription"), action: action)
                .rowButtonStyle()
        }
    }
}

#if DEBUG
#Preview {
    Form {
        SupportOffersSections(store: SupportStore(service: PreviewSupportService()), lockedAppIcons: EmptyView()) {}
    }
}
#endif
