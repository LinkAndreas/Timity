import SwiftUI

struct ActiveSubscriptionRow: View {
    let subscription: ActiveSupportSubscription

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Thank you for supporting the continued development of the app"))
                if let date = subscription.expirationDate?.formatted(date: .abbreviated, time: .omitted) {
                    Text(subscription.willAutoRenew ? String(localized: "Renews on \(date)") : String(localized: "Ends on \(date)"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
        }
    }
}

#if DEBUG
#Preview {
    List {
        ActiveSubscriptionRow(subscription: ActiveSupportSubscription(productID: .yearly, expirationDate: .now.addingTimeInterval(200 * 86_400), willAutoRenew: true))
    }
}
#endif
