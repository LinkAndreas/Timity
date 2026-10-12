import Foundation

/// Every Support the Developer product, as configured in App Store Connect.
///
/// Identifiers live only here. Names and prices are never hard-coded — they come
/// from the App Store at runtime, so they can be changed in App Store Connect
/// without an app update. See `Docs/AppStoreConnect-Support.md`.
enum SupportProductID: String, CaseIterable, Identifiable, Sendable {
    // One-time support (consumables, so people can support more than once).
    case small = "de.link.timity.support.small"
    case medium = "de.link.timity.support.medium"
    case generous = "de.link.timity.support.generous"

    // Recurring support (auto-renewable subscriptions in one group).
    case monthly = "de.link.timity.support.monthly"
    case yearly = "de.link.timity.support.yearly"

    enum Kind: Sendable {
        case oneTime
        case subscription
    }

    var id: String { rawValue }

    var kind: Kind {
        switch self {
        case .small, .medium, .generous: .oneTime
        case .monthly, .yearly: .subscription
        }
    }

    /// Decorative emoji shown next to the App Store's product name.
    var emoji: String {
        switch self {
        case .small: "☕"
        case .medium: "❤️"
        case .generous: "⭐"
        case .monthly: "🌱"
        case .yearly: "🌳"
        }
    }
}
