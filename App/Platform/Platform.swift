import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The few things iPhone, iPad and Mac do differently, in one place, so views stay
/// the same on every platform.
enum Platform {
    /// Timity's page in Settings on iPhone and iPad, or the Privacy & Security pane on the Mac.
    static var appSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        #endif
    }

    /// Where notifications for Timity are turned on.
    static var notificationSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #endif
    }

    /// The app icon picker's note: the Home Screen on iPhone and iPad, the Dock on the Mac.
    static var appIconNoteKey: String {
        #if os(macOS)
        "settings.pickTheIconTimityShows.mac"
        #else
        "settings.pickTheIconTimityShows"
        #endif
    }

    /// Puts `text` on the clipboard.
    @MainActor
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    /// Shows an alternate app icon, or the primary one for `nil`: on the Home Screen on
    /// iPhone and iPad, in the Dock on the Mac, where it's set again at each launch.
    @MainActor
    static func setAppIcon(_ alternateIconName: String?) async throws {
        #if os(iOS)
        try await UIApplication.shared.setAlternateIconName(alternateIconName)
        #else
        NSApp.applicationIconImage = alternateIconName.flatMap { NSImage(named: $0) }
        #endif
    }

    /// "iPhone", "iPad" or "Mac", and the system version, for support mail.
    @MainActor
    static var deviceDescription: (name: String, system: String) {
        #if os(iOS)
        (UIDevice.current.model, "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return ("Mac", "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        #endif
    }
}

#if os(macOS)
/// The color names the iOS code uses, on the Mac.
extension Color {
    init(uiColor: NSColor) { self.init(nsColor: uiColor) }
}

extension NSColor {
    static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
    static var systemGroupedBackground: NSColor { .windowBackgroundColor }
    static var systemBackground: NSColor { .windowBackgroundColor }
}
#endif
