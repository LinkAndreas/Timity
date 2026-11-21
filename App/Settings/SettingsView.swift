import SwiftUI

struct SettingsView<Importer: View, AppIcons: View, CloudSync: View>: View {
    @Binding var appearance: AppSettings.Appearance
    @Binding var accentColor: EventColor
    @Binding var milestoneAlerts: Bool
    @Binding var sharesDiagnostics: Bool
    @Binding var syncsWithICloud: Bool
    let syncState: () -> CloudSyncState
    let importer: () -> Importer
    /// The app icon picker.
    let appIcons: () -> AppIcons
    /// The iCloud page, with what helps when events don't sync.
    let cloudSync: () -> CloudSync
    /// Exporting and importing events as files.
    let backup: BackupActions
    /// Goes to a feature from What's New.
    let showFeature: (WhatsNew.Feature.Destination) -> Void
    /// The version history: a sheet on the Mac, a page pushed on iPhone and iPad; What's
    /// New opens it too.
    @Binding var isShowingVersionHistory: Bool
    /// Asks for permission to send notifications; `false` when they're off.
    let requestNotificationPermission: () async -> Bool

    @State private var isImporting = false
    @State private var isShowingWhatsNew = false
    @State private var isTestBuild = false
    #if os(macOS)
    /// The room a sheet opened inside a tab needs, as the export or iCloud help.
    @State private var innerSheetSize = CGSize.zero
    #endif

    var body: some View {
        // One list on iPhone and iPad; tabs in the Mac's Settings window, as Mac apps have
        // them, the window fitting each tab.
        Group {
            #if os(macOS)
            TabView {
                Tab("settings.general", systemImage: "gearshape") {
                    Form {
                        AppearanceSection(appearance: $appearance, accentColor: $accentColor)
                        appIcons()
                        CountdownsSection(milestoneAlerts: $milestoneAlerts, requestNotificationPermission: requestNotificationPermission)
                        PrivacySection(sharesDiagnostics: $sharesDiagnostics)
                    }
                    .modifier(SettingsTabFrame(height: 600, sheet: sheetSize))
                }
                Tab("common.events", systemImage: "calendar") {
                    Form {
                        ImportSection { isImporting = true }
                        BackupSection(actions: backup)
                    }
                    .modifier(SettingsTabFrame(height: 340, sheet: sheetSize))
                }
                Tab("common.icloud", systemImage: "icloud") {
                    cloudSync()
                        .modifier(SettingsTabFrame(height: 600, sheet: sheetSize))
                }
                Tab("settings.about", systemImage: "info.circle") {
                    Form {
                        AboutSettingsSection(showWhatsNew: { isShowingWhatsNew = true }, showVersionHistory: { isShowingVersionHistory = true })
                        TestingSection(isTestBuild: isTestBuild)
                    }
                    .modifier(SettingsTabFrame(height: isTestBuild ? 500 : 380, sheet: sheetSize))
                }
            }
            // A sheet opened further down, as the export or iCloud help, says how much room it needs.
            .onPreferenceChange(SettingsSheetSizeKey.self) { size in
                MainActor.assumeIsolated { innerSheetSize = size }
            }
            #else
            NavigationStack {
                Form {
                    AppearanceSection(appearance: $appearance, accentColor: $accentColor)
                    appIcons()
                    CountdownsSection(milestoneAlerts: $milestoneAlerts, requestNotificationPermission: requestNotificationPermission)
                    ImportSection { isImporting = true }
                    BackupSection(actions: backup)
                    Section("common.icloud") {
                        Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
                        NavigationLink {
                            cloudSync()
                        } label: {
                            CloudSyncStatusLabel(state: syncState())
                        }
                    }
                    PrivacySection(sharesDiagnostics: $sharesDiagnostics)
                    AboutSettingsSection(showWhatsNew: { isShowingWhatsNew = true }, showVersionHistory: { isShowingVersionHistory = true })
                    TestingSection(isTestBuild: isTestBuild)
                }
                .navigationTitle("common.settings")
                // Opened from What's New; the row in About pushes it on its own.
                .navigationDestination(isPresented: $isShowingVersionHistory) {
                    VersionHistoryView()
                }
            }
            #endif
        }
        .task { isTestBuild = await TestBuild.isRunning }
        .sheet(isPresented: $isImporting) {
            importer()
        }
        .sheet(isPresented: $isShowingWhatsNew) {
            WhatsNewView(onTry: showFeature)
                .macSheetSize()
        }
        #if os(macOS)
        .sheet(isPresented: $isShowingVersionHistory) {
            NavigationStack {
                VersionHistoryView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") { isShowingVersionHistory = false }
                        }
                    }
            }
            .macSheetSize()
        }
        #endif
    }
}

private struct AppearanceSection: View {
    @Binding var appearance: AppSettings.Appearance
    @Binding var accentColor: EventColor

    var body: some View {
        Section("common.appearance") {
            Picker("common.appearance", selection: $appearance) {
                ForEach(AppSettings.Appearance.allCases) { appearance in
                    Text(appearance.name).tag(appearance)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.tint")
                ColorPalette(selection: $accentColor)
            }
        }
    }
}

private struct CountdownsSection: View {
    @Binding var milestoneAlerts: Bool
    /// Asks for permission to send notifications; `false` when they're off.
    let requestNotificationPermission: () async -> Bool

    /// Whether milestone alerts are on while notifications are off, so none would arrive.
    @State private var areNotificationsBlocked = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            Toggle("settings.milestoneAlerts", isOn: $milestoneAlerts)
                .task(id: milestoneAlerts) {
                    areNotificationsBlocked = milestoneAlerts ? !(await requestNotificationPermission()) : false
                }
        } header: {
            Text("settings.countdowns")
        } footer: {
            if areNotificationsBlocked {
                NotificationsBlockedNote { openURL($0) }
            }
        }
    }
}

private struct ImportSection: View {
    let startImport: () -> Void

    var body: some View {
        Section("settings.yourEvents") {
            Button(action: startImport) {
                RowLabel("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down")
            }
            .rowButtonStyle()
        }
    }
}

private struct BackupSection: View {
    /// Exporting and importing events as files.
    let actions: BackupActions

    var body: some View {
        Section {
            BackupControls(actions: actions)
        } header: {
            Text("settings.backup")
        } footer: {
            Text("settings.aBackupKeepsEveryDetail")
        }
    }
}

private struct PrivacySection: View {
    @Binding var sharesDiagnostics: Bool

    var body: some View {
        Section {
            Toggle("settings.shareCrashReports", isOn: $sharesDiagnostics)
        } header: {
            Text("settings.privacy")
        } footer: {
            #if os(macOS)
            Text("settings.whenTimityCrashesOrFreezes.mac")
            #else
            Text("settings.whenTimityCrashesOrFreezes")
            #endif
        }
    }
}

/// What's New, the version history, and rating, feedback, the website, the privacy policy
/// and the version.
private struct AboutSettingsSection: View {
    let showWhatsNew: () -> Void
    /// Opens the version history in a sheet on the Mac.
    let showVersionHistory: () -> Void

    var body: some View {
        Section("settings.about") {
            Button(action: showWhatsNew) {
                Label {
                    Text("settings.whatsNew")
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "sparkles")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .rowButtonStyle()
            VersionHistoryLink(showOnMac: showVersionHistory)
            AboutSection()
        }
    }
}

/// For testers only, so in English alone.
private struct TestingSection: View {
    let isTestBuild: Bool

    @AppStorage(TipTesting.showAgainKey) private var showsTipsAgain = false

    var body: some View {
        if isTestBuild {
            Section {
                Button {
                    showsTipsAgain = true
                } label: {
                    Label {
                        Text(verbatim: showsTipsAgain ? "Tips Show Again at Next Start" : "Show Tips Again")
                            #if os(macOS)
                            .foregroundStyle(showsTipsAgain ? Color.secondary : Color.primary)
                            #endif
                    } icon: {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.tint)
                    }
                }
                .rowButtonStyle()
                .disabled(showsTipsAgain)
            } header: {
                Text(verbatim: "Testing")
            } footer: {
                Text(verbatim: "Only in TestFlight and Xcode builds. Brings every tip back once, all at once rather than one a day, the next time Timity starts: quit Timity and open it again. Closing a tip puts it away again.")
            }
        }
    }
}

#if os(macOS)
extension SettingsView {
    /// The room the open sheet needs in the Settings window; nothing while none is open.
    fileprivate var sheetSize: CGSize {
        if isImporting || isShowingWhatsNew || isShowingVersionHistory {
            return SettingsSheetSizeKey.sheet
        }
        return innerSheetSize
    }
}

/// The room a sheet opened from a Settings tab needs in the window.
struct SettingsSheetSizeKey: PreferenceKey {
    /// A sheet of the usual size, with a margin around it.
    static let sheet = CGSize(width: 620, height: 640)
    /// The export preview, wider for its table.
    static let wideSheet = CGSize(width: 760, height: 640)

    static let defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

/// A Settings tab at its own size, grown while a sheet is open: the Mac cuts off a sheet
/// larger than its window, so the window makes room for it and shrinks back after.
private struct SettingsTabFrame: ViewModifier {
    let height: CGFloat
    let sheet: CGSize

    func body(content: Content) -> some View {
        content.frame(width: max(620, sheet.width), height: max(height, sheet.height))
    }
}
#endif

/// A button row's title and symbol. On the Mac the title in the text colour and the symbol in
/// the tint, as Settings' rows are there; elsewhere the whole label in the tint.
struct RowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        #if os(macOS)
        Label {
            Text(title)
                .foregroundStyle(Color.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
        #else
        Label(title, systemImage: systemImage)
        #endif
    }
}

nonisolated extension Bundle {
    /// "4.0 (12)".
    var versionDescription: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Rating, feedback, the website, the privacy policy and the version — each answering a tap at once:
/// a haptic, and an arrow on rows that leave the app.
private struct AboutSection: View {
    @State private var isShowingMailHelp = false
    @State private var hasCopiedVersion = false

    var body: some View {
        // The App Store's own page: the in-app prompt may show nothing when tapped,
        // as the system limits how often it appears.
        AboutLinkRow(title: "settings.rateTimity", systemImage: "star", url: URL(string: "https://apps.apple.com/app/id491746507?action=write-review")!)
        AboutLinkRow(title: "settings.sendFeedback", systemImage: "envelope", url: SupportMail.feedbackURL!) {
            isShowingMailHelp = true
        }
        AboutLinkRow(title: "settings.timityWebsite", systemImage: "globe", url: WebsiteLinks.home)
        AboutLinkRow(title: "settings.privacyPolicy", systemImage: "hand.raised", url: WebsiteLinks.privacyPolicy)
        Button {
            Platform.copy("Timity \(Bundle.main.versionDescription)")
            withAnimation { hasCopiedVersion = true }
        } label: {
            LabeledContent("settings.version") {
                Text(hasCopiedVersion ? String(localized: "settings.copied") : Bundle.main.versionDescription)
                    .contentTransition(.opacity)
            }
        }
        .rowButtonStyle()
        .tint(.primary)
        .accessibilityHint(Text("settings.copiesTheVersion"))
        .sensoryFeedback(.success, trigger: hasCopiedVersion) { _, copied in copied }
        .task(id: hasCopiedVersion) {
            guard hasCopiedVersion else { return }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { hasCopiedVersion = false }
        }
        .alert("settings.cantOpenMail", isPresented: $isShowingMailHelp) {
            Button("settings.copyAddress") { Platform.copy(SupportMail.address) }
            Button("settings.ok", role: .cancel) {}
        } message: {
            Text("settings.writeToFromAnyMail \(SupportMail.address)")
        }
    }
}

/// A row that opens `url` with a haptic, or calls `onFailure` when nothing can open it.
private struct AboutLinkRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let url: URL
    var onFailure: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            openURL(url) { accepted in
                if !accepted { onFailure?() }
            }
        } label: {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: systemImage)
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .rowButtonStyle()
        .sensoryFeedback(.selection, trigger: taps)
    }
}
