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
