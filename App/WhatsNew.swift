import SwiftUI

/// What a release brings, shown once to people who already used Timity, and any
/// time from Settings.
enum WhatsNew {
    /// The release these features came with; raising it shows the sheet again.
    static let version = "4.8"

    struct Feature: Identifiable {
        enum Destination: Hashable {
            case astronomy, calculator(CalculatorTool), settings
        }

        let id = UUID()
        let symbol: String
        let color: EventColor
        let title: LocalizedStringKey
        let text: LocalizedStringKey
        var destination: Destination?
    }

    static let features: [Feature] = [
        Feature(
            symbol: "moon.stars.fill", color: .indigo, title: "common.astronomy",
            text: "whatsNew.theSunTabNowShows",
            destination: .astronomy
        ),
        Feature(
            symbol: "calendar.circle.fill", color: .mint, title: "common.calendarConverter",
            text: "whatsNew.seeAnyDateInThe",
            destination: .calculator(.calendarConverter)
        ),
        Feature(
            symbol: "clock.fill", color: .blue, title: "whatsNew.timesInCalculators",
            text: "whatsNew.timeBetweenFindADate",
            destination: .calculator(.timeBetween)
        ),
        Feature(
            symbol: "globe.europe.africa.fill", color: .cyan, title: "whatsNew.timeZonesClearer",
            text: "whatsNew.changeTheTimeInAny",
            destination: .calculator(.timeZones)
        ),
        Feature(
            symbol: "bed.double.fill", color: .nightfall, title: "whatsNew.aBetterBedtime",
            text: "whatsNew.planFromYourWakeUp",
            destination: .calculator(.sleep)
        ),
        Feature(
            symbol: "square.grid.2x2.fill", color: .purple, title: "whatsNew.newWidgets",
            text: "whatsNew.aMoonWidgetAndComplication"
        ),
        Feature(
            symbol: "chart.bar.fill", color: .orange, title: "whatsNew.progressAtAGlance",
            text: "whatsNew.eventsWithProgressShowIt"
        ),
        Feature(
            symbol: "square.and.arrow.up.fill", color: .green, title: "whatsNew.exportAndImport",
            text: "whatsNew.keepEveryEventAsA",
            destination: .settings
        ),
    ]

    /// After an update for people who already used Timity; new users have the welcome instead.
    static func shouldShow(lastSeen: String?, hasCompletedOnboarding: Bool) -> Bool {
        hasCompletedOnboarding && lastSeen != version
    }
}

/// The release's new features, each with a way to try it.
struct WhatsNewView: View {
    /// Shows a feature; the sheet closes first.
    let onTry: (WhatsNew.Feature.Destination) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .scaledFont(size: 52)
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityHidden(true)
                        Text("whatsNew.whatsNewInTimity")
                            .font(.largeTitle.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    ForEach(WhatsNew.features) { feature in
                        row(feature)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("common.continue")
                        .font(.headline)
                        .frame(maxWidth: 400)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                // Return and Escape close it too, as Mac sheets do.
                .keyboardShortcut(.defaultAction)
                .padding()
            }
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
            #else
            // On the Mac a close button would sit beside Continue and do the same.
            .onExitCommand { dismiss() }
            #endif
        }
    }

    private func row(_ feature: WhatsNew.Feature) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(feature.color.color.gradient, in: .rect(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let destination = feature.destination {
                    Button("whatsNew.tryIt") {
                        dismiss()
                        onTry(destination)
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderless)
                    .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension Navigator {
    /// Goes to a feature from What's New.
    func show(_ destination: WhatsNew.Feature.Destination) {
        switch destination {
        case .astronomy:
            tab = .sun
        case let .calculator(tool):
            calculator = tool
            tab = .calculators
        case .settings:
            tab = .settings
        }
    }
}
