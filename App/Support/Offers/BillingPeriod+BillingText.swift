import Foundation

extension BillingPeriod {
    /// In the app's language — StoreKit's own wording follows the App Store
    /// storefront, which can differ from the language the app runs in.
    var billingText: String {
        switch self {
        case .day: String(localized: "Billed daily")
        case .week: String(localized: "Billed weekly")
        case .month: String(localized: "Billed monthly")
        case .year: String(localized: "Billed yearly")
        }
    }
}
