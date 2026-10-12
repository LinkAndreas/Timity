import Foundation
import OSLog
import SwiftData

let logger = Logger(subsystem: "de.link.timity", category: "app")

/// Where events are stored: one SwiftData store in the app group, so the widgets
/// read what the app writes, mirrored to the user's private iCloud database.
enum TimityStore {
    static let appGroup = "group.de.link.timity"
    static let cloudContainer = "iCloud.de.link.timity"

    /// The container for this process. The apps sync with iCloud; extensions
    /// (widgets, complications) only read the store and leave syncing to the app.
    static let container: ModelContainer = makeContainer(syncsWithICloud: isApp)

    /// Whether this process is an app rather than an extension.
    private static var isApp: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func makeContainer(syncsWithICloud: Bool, inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([Event.self])
        func configuration(cloud: Bool) -> ModelConfiguration {
            ModelConfiguration(
                "Timity",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true,
                groupContainer: inMemory ? .none : .identifier(appGroup),
                cloudKitDatabase: cloud ? .private(cloudContainer) : .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration(cloud: syncsWithICloud && !inMemory))
        } catch {
            // Without iCloud entitlements (e.g. a simulator build without a team)
            // the app still works with the same store, just without syncing.
            logger.error("Couldn't open the iCloud store: \(error)")
        }
        do {
            return try ModelContainer(for: schema, configurations: configuration(cloud: false))
        } catch {
            logger.fault("Couldn't open the store, falling back to memory: \(error)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // An in-memory store can't fail to open.
            return try! ModelContainer(for: schema, configurations: memory)
        }
    }

    /// Every event as a snapshot, for widgets and intents.
    static func snapshots(in container: ModelContainer = TimityStore.container) -> [EventSnapshot] {
        let context = ModelContext(container)
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        return events.map(\.snapshot)
    }
}
