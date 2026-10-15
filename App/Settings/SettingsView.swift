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

    @State private var isImporting = false
    @State private var isShowingSupport = false

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
                                Text("Support the Developer")
                                    .font(.headline)
                                Text(isSupporter ? LocalizedStringKey("Thank you for your support!") : LocalizedStringKey("Timity is free. Support keeps it growing."))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.name).tag(appearance)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tint")
                        ColorPalette(selection: $accentColor)
                    }
                }

                Section {
                    Toggle("Show Weeks", isOn: $showsWeeks)
                    Toggle("Show Seconds", isOn: $showsSeconds)
                    Toggle("Milestone Alerts", isOn: $milestoneAlerts)
                } header: {
                    Text("Countdowns")
                } footer: {
                    Text("With weeks on, 17 days read as 2 weeks and 3 days. Milestone alerts celebrate round numbers since your events, such as 10,000 days.")
                }

                Section {
                    Button("Import from Contacts and Calendar", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                }

                Section("iCloud") {
                    Toggle("Sync with iCloud", isOn: $syncsWithICloud)
                    NavigationLink {
                        cloudSync()
                    } label: {
                        CloudSyncStatusLabel(state: syncState())
                    }
                }

                Section {
                    Toggle("Share Crash Reports", isOn: $sharesDiagnostics)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("When Timity crashes or freezes, iOS gives it a technical report. With this on, Timity sends it to the developer through iCloud, without your name, your events or anything you entered, so the problem can be fixed.")
                }

                Section("About") {
                    AboutSection()
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isImporting) {
                importer()
            }
            .sheet(isPresented: $isShowingSupport) {
                support()
            }
        }
    }
}

extension Bundle {
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
        AboutLinkRow(title: "Rate Timity", systemImage: "star", url: URL(string: "https://apps.apple.com/app/id491746507?action=write-review")!)
        AboutLinkRow(title: "Send Feedback", systemImage: "envelope", url: URL(string: "mailto:\(Self.feedbackAddress)?subject=Timity")!) {
            isShowingMailHelp = true
        }
        AboutLinkRow(title: "Timity Website", systemImage: "globe", url: URL(string: "https://timity.linkandreas.de")!)
        Button {
            UIPasteboard.general.string = "Timity \(Bundle.main.versionDescription)"
            withAnimation { hasCopiedVersion = true }
        } label: {
            LabeledContent("Version") {
                Text(hasCopiedVersion ? String(localized: "Copied") : Bundle.main.versionDescription)
                    .contentTransition(.opacity)
            }
        }
        .tint(.primary)
        .accessibilityHint(Text("Copies the version"))
        .sensoryFeedback(.success, trigger: hasCopiedVersion) { _, copied in copied }
        .task(id: hasCopiedVersion) {
            guard hasCopiedVersion else { return }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { hasCopiedVersion = false }
        }
        .alert("Can't Open Mail", isPresented: $isShowingMailHelp) {
            Button("Copy Address") { UIPasteboard.general.string = Self.feedbackAddress }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Write to \(Self.feedbackAddress) from any mail app.")
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
