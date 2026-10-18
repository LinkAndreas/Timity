import StoreKit
import SwiftUI

/// Support the Developer: a quiet, optional way to pay for Timity's development.
/// No feature is locked — the app stays fully free. Recurring support unlocks the
/// alternative app icons as a thank-you.
struct SupportView<AppIcons: View>: View {
    let store: SupportStore
    /// The app icon picker, unlocked or locked.
    let appIcons: (_ isUnlocked: Bool) -> AppIcons

    @Environment(\.openURL) private var openURL
    @State private var isManagingSubscription = false

    var body: some View {
        Form {
            Section {
                SupportHeader()
            }
            .listRowBackground(Color.clear)

            if let subscription = store.activeSubscription {
                Section {
                    ActiveSubscriptionRow(subscription: subscription)
                }

                // Supporters find their icons right under their thank-you; everyone
                // else sees them locked next to the subscriptions that unlock them.
                appIcons(true)
            }

            if let status = store.status {
                Section {
                    SupportStatusRow(status: status)
                }
            }

            SupportOffersSections(store: store, lockedAppIcons: appIcons(false)) {
                isManagingSubscription = true
            }

            Section {
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    HStack {
                        Text(String(localized: "support.restorePurchases"))
                        Spacer()
                        if store.isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(store.isBusy)

                Link(String(localized: "support.termsOfUse"), destination: SupportLinks.termsOfUse)
                Link(String(localized: "support.privacyPolicy"), destination: SupportLinks.privacyPolicy)
            }
        }
        // Loading isn't animated: the offers often arrive while the sheet is still sliding
        // up, and the placeholders have the same layout, so swapping them in place is seamless.
        .animation(.default, value: store.status)
        .animation(.default, value: store.activeSubscription)
        // Every completed purchase — one-time or a new subscription — is celebrated.
        .overlay {
            CelebrationBurst(trigger: store.celebrationCount)
                .ignoresSafeArea()
        }
        .sensoryFeedback(.success, trigger: store.celebrationCount)
        #if os(iOS)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        #else
        // The Mac manages subscriptions in the App Store app.
        .onChange(of: isManagingSubscription) { _, isOn in
            guard isOn else { return }
            isManagingSubscription = false
            if let url = URL(string: "macappstore://apps.apple.com/account/subscriptions") { openURL(url) }
        }
        #endif
        .task { await store.load() }
    }
}

#if DEBUG
#Preview("Support") {
    NavigationStack {
        SupportView(store: SupportStore(service: PreviewSupportService())) { _ in EmptyView() }
            .navigationTitle(String(localized: "common.supportTheDeveloper"))
    }
}

#Preview("Subscribed") {
    NavigationStack {
        SupportView(store: SupportStore(service: PreviewSupportService(
            subscription: ActiveSupportSubscription(productID: .yearly, expirationDate: .now.addingTimeInterval(200 * 86_400), willAutoRenew: true)
        ))) { _ in EmptyView() }
    }
}
#endif
