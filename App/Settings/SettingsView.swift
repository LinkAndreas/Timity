import CloudKit
import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SupportStore.self) private var supportStore
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @State private var iCloudStatus: CKAccountStatus?
    @State private var isImporting = false
    @State private var isShowingSupport = false

    var body: some View {
        @Bindable var settings = settings

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
                                Text(supportStore.isSupporter ? LocalizedStringKey("Thank you for your support!") : LocalizedStringKey("Timity is free. Support keeps it growing."))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(.primary)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppSettings.Appearance.allCases) { appearance in
                            Text(appearance.name).tag(appearance)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tint")
                        ColorPalette(selection: $settings.accentColor)
                    }
                }

                Section {
                    Toggle("Show Weeks", isOn: $settings.showsWeeks)
                    Toggle("Show Seconds", isOn: $settings.showsSeconds)
                    Toggle("Milestone Alerts", isOn: $settings.milestoneAlerts)
                        .onChange(of: settings.milestoneAlerts) { _, isOn in
                            Task {
                                if isOn { await ReminderScheduler.requestAuthorization() }
                                await ReminderScheduler.reschedule(container: modelContext.container)
                            }
                        }
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
                iCloudStatus = try? await CKContainer(identifier: TimityStore.cloudContainer).accountStatus()
            }
            .sheet(isPresented: $isImporting) {
                ImportView()
            }
            .sheet(isPresented: $isShowingSupport) {
                SupportSheet()
            }
        }
    }

    @ViewBuilder
    private var iCloudRow: some View {
        switch iCloudStatus {
        case .available:
            Label("Syncing with iCloud", systemImage: "checkmark.icloud.fill")
                .foregroundStyle(.green)
        case .noAccount:
            Label("Sign in to iCloud in Settings to sync your events.", systemImage: "icloud.slash")
        case .restricted, .couldNotDetermine, .temporarilyUnavailable:
            Label("iCloud is unavailable right now. Your events are kept on this device.", systemImage: "exclamationmark.icloud")
        case nil:
            Label("Checking iCloud…", systemImage: "icloud")
                .foregroundStyle(.secondary)
        @unknown default:
            Label("iCloud", systemImage: "icloud")
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
