import Foundation
import SwiftData

/// The widget extensions' composition root. WidgetKit creates bundles and widgets
/// with `init()`, so those take their dependencies from here and pass them on to
/// their timeline providers.
enum WidgetComposition {
    // Extensions only read the store and leave syncing to the apps.
    static let database = EventDatabase(syncsWithICloud: false)
    static let reader = SwiftDataEventReader(database: database)
    static let sharedSettings = SharedSettings(store: UserDefaults(suiteName: AppGroup.identifier) ?? .standard)

    /// Hands the intents widgets run, such as pinning an event, what they need.
    @MainActor
    static func registerIntentDependencies() {
        IntentDependencies.register(
            repository: SwiftDataEventRepository(database: database),
            reader: reader,
            widgets: WidgetKitRefresher(),
            sharedSettings: sharedSettings
        )
    }
}
