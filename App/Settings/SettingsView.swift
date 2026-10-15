import SwiftUI
import UIKit

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

    @State private var isImporting = false
    @State private var isShowingSupport = false
    @State private var isShowingWhatsNew = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        isShowingSupport = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.fill")
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
                } header: {
                    Text("settings.countdowns")
                } footer: {
                    Text("settings.withWeeksOn17Days")
                }

                Section {
                    Button("common.importFromContactsAndCalendar", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                    BackupControls(actions: backup)
                } header: {
                    Text("settings.yourEvents")
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
            }
            .navigationTitle("common.settings")
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
    private static let feedbackAddress = "feedback@linkandreas.de"

    @State private var isShowingMailHelp = false
    @State private var hasCopiedVersion = false

    var body: some View {
        // The App Store's own page: the in-app prompt may show nothing when tapped,
        // as the system limits how often it appears.
        AboutLinkRow(title: "settings.rateTimity", systemImage: "star", url: URL(string: "https://apps.apple.com/app/id491746507?action=write-review")!)
        AboutLinkRow(title: "settings.sendFeedback", systemImage: "envelope", url: URL(string: "mailto:\(Self.feedbackAddress)?subject=Timity")!) {
            isShowingMailHelp = true
        }
        AboutLinkRow(title: "settings.timityWebsite", systemImage: "globe", url: URL(string: "https://timity.linkandreas.de")!)
        Button {
            UIPasteboard.general.string = "Timity \(Bundle.main.versionDescription)"
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
            Button("settings.copyAddress") { UIPasteboard.general.string = Self.feedbackAddress }
            Button("settings.ok", role: .cancel) {}
        } message: {
            Text("settings.writeToFromAnyMail \(Self.feedbackAddress)")
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
