import SwiftUI

struct SettingsView<Importer: View, Support: View, CloudSync: View>: View {
    @Binding var appearance: AppSettings.Appearance
    @Binding var accentColor: EventColor
    @Binding var showsWeeks: Bool
    @Binding var showsSeconds: Bool
    @Binding var milestoneAlerts: Bool
    @Binding var sharesDiagnostics: Bool
    /// Whether recurring support is active.
    let isSupporter: Bool
    @Binding var syncsWithICloud: Bool
    let syncState: () -> CloudSyncState
    let importer: () -> Importer
    let support: () -> Support
    /// The iCloud page, with what helps when events don't sync.
    let cloudSync: () -> CloudSync
    /// Exporting and importing events as files.
    let backup: BackupActions
    /// Goes to a feature from What's New.
    let showFeature: (WhatsNew.Feature.Destination) -> Void
    /// Asks for permission to send notifications; `false` when they're off.
    let requestNotificationPermission: () async -> Bool

    @State private var isImporting = false
    @State private var isShowingSupport = false
    @State private var isShowingWhatsNew = false
    /// Whether milestone alerts are on while notifications are off, so none would arrive.
    @State private var areNotificationsBlocked = false
    @Environment(\.openURL) private var openURL

    @State private var isTestBuild = false
    @AppStorage(TipTesting.showAgainKey) private var showsTipsAgain = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        isShowingSupport = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.fill")
                                .accessibilityHidden(true)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.pink.gradient, in: .rect(cornerRadius: 11, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("common.supportTheDeveloper")
                                    .font(.headline)
                                Text(isSupporter ? LocalizedStringKey("settings.thankYouForYourSupport") : LocalizedStringKey("settings.timityIsFreeSupportKeeps"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }

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

                Section {
                    Toggle("settings.showWeeks", isOn: $showsWeeks)
                    Toggle("settings.showSeconds", isOn: $showsSeconds)
                    Toggle("settings.milestoneAlerts", isOn: $milestoneAlerts)
                        .task(id: milestoneAlerts) {
                            areNotificationsBlocked = milestoneAlerts ? !(await requestNotificationPermission()) : false
                        }
                } header: {
                    Text("settings.countdowns")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.withWeeksOn17Days")
                        if areNotificationsBlocked {
                            NotificationsBlockedNote { openURL($0) }
                        }
                    }
                }

                Section("settings.yourEvents") {
                    Button("common.importBirthdaysAndEvents", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                }

                Section {
                    BackupControls(actions: backup)
                } header: {
                    Text("settings.backup")
                } footer: {
                    Text("settings.aBackupKeepsEveryDetail")
                }

                Section("common.icloud") {
                    Toggle("common.syncWithICloud", isOn: $syncsWithICloud)
                    NavigationLink {
                        cloudSync()
                    } label: {
                        CloudSyncStatusLabel(state: syncState())
                    }
                }

                Section {
                    Toggle("settings.shareCrashReports", isOn: $sharesDiagnostics)
                } header: {
                    Text("settings.privacy")
                } footer: {
                    Text("settings.whenTimityCrashesOrFreezes")
                }

                Section("settings.about") {
                    Button {
                        isShowingWhatsNew = true
                    } label: {
                        Label {
                            Text("settings.whatsNew")
                                .foregroundStyle(Color.primary)
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                    }
                    AboutSection()
                }

                // For testers only, so in English alone.
                if isTestBuild {
                    Section {
                        Button {
                            showsTipsAgain = true
                        } label: {
                            Text(verbatim: showsTipsAgain ? "Tips Show Again at Next Start" : "Show Tips Again")
                        }
                        .disabled(showsTipsAgain)
                    } header: {
                        Text(verbatim: "Testing")
                    } footer: {
                        Text(verbatim: "Only in TestFlight and Xcode builds. Brings every tip back once, all at once rather than one a day, the next time Timity starts: swipe it away in the app switcher and open it again. Closing a tip puts it away again.")
                    }
                }
            }
            .navigationTitle("common.settings")
            .task { isTestBuild = await TestBuild.isRunning }
            .sheet(isPresented: $isImporting) {
                importer()
            }
            .sheet(isPresented: $isShowingSupport) {
                support()
            }
            .sheet(isPresented: $isShowingWhatsNew) {
                WhatsNewView(onTry: showFeature)
            }
        }
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

/// Rating, feedback, the website and the version — each answering a tap at once:
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
        AboutLinkRow(title: "settings.timityWebsite", systemImage: "globe", url: URL(string: "https://timity.linkandreas.de")!)
        Button {
            Platform.copy("Timity \(Bundle.main.versionDescription)")
            withAnimation { hasCopiedVersion = true }
        } label: {
            LabeledContent("settings.version") {
                Text(hasCopiedVersion ? String(localized: "settings.copied") : Bundle.main.versionDescription)
                    .contentTransition(.opacity)
            }
        }
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
        .sensoryFeedback(.selection, trigger: taps)
    }
}
