import OSLog

nonisolated let logger = Logger(subsystem: "de.link.timity", category: "app")

/// The containers the app, its widgets and the Watch share.
nonisolated enum AppGroup {
    /// The app group whose store and user defaults the widgets read.
    static let identifier = "group.de.link.timity"
    /// The user's private iCloud database the events sync through.
    static let cloudContainer = "iCloud.de.link.timity"
}
