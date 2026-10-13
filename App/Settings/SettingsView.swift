import StoreKit
import SwiftUI

struct SettingsView<Importer: View, Support: View>: View {
    @Binding var appearance: AppSettings.Appearance
    @Binding var accentColor: EventColor
    @Binding var showsWeeks: Bool
    @Binding var showsSeconds: Bool
    @Binding var milestoneAlerts: Bool
    /// Whether recurring support is active.
    let isSupporter: Bool
    let iCloudStatus: () async -> CloudAccountStatus
    let importer: () -> Importer
    let support: () -> Support

    @Environment(\.requestReview) private var requestReview
    @State private var cloudStatus: CloudAccountStatus?
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

                Section {
                    iCloudRow
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Your events sync with your iPhone, iPad and Apple Watch through your private iCloud account. Only you can see them.")
                }

                Section("About") {
                    Button("Rate Timity", systemImage: "star") {
                        requestReview()
                    }
                    Link(destination: URL(string: "https://apps.apple.com/app/id491746507?action=write-review")!) {
                        Label("Write a Review", systemImage: "square.and.pencil")
                    }
                    Link(destination: URL(string: "mailto:timity@appleteam.de?subject=Timity")!) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                }
            }
            .navigationTitle("Settings")
            .task {
                cloudStatus = await iCloudStatus()
            }
            .sheet(isPresented: $isImporting) {
                importer()
            }
            .sheet(isPresented: $isShowingSupport) {
                support()
            }
        }
    }

    @ViewBuilder
    private var iCloudRow: some View {
        switch cloudStatus {
        case .available:
            Label("Syncing with iCloud", systemImage: "checkmark.icloud.fill")
                .foregroundStyle(.green)
        case .noAccount:
            Label("Sign in to iCloud in Settings to sync your events.", systemImage: "icloud.slash")
        case .unavailable:
            Label("iCloud is unavailable right now. Your events are kept on this device.", systemImage: "exclamationmark.icloud")
        case nil:
            Label("Checking iCloud…", systemImage: "icloud")
                .foregroundStyle(.secondary)
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
