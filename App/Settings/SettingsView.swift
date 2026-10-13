import StoreKit
import SwiftUI

struct SettingsView<Importer: View, Support: View, CloudSync: View>: View {
    @Binding var appearance: AppSettings.Appearance
    @Binding var accentColor: EventColor
    @Binding var showsWeeks: Bool
    @Binding var showsSeconds: Bool
    @Binding var milestoneAlerts: Bool
    /// Whether recurring support is active.
    let isSupporter: Bool
    @Binding var syncsWithICloud: Bool
    let syncState: () -> CloudSyncState
    let importer: () -> Importer
    let support: () -> Support
    /// The iCloud page, with what helps when events don't sync.
    let cloudSync: () -> CloudSync

    @Environment(\.requestReview) private var requestReview
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
