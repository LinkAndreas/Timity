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
            symbol: "moon.stars.fill", color: .indigo, title: "Astronomy",
            text: "The Sun tab now shows the Moon too: today's phase, a month of phases, moonrise and moonset, and the year's full moons.",
            destination: .astronomy
        ),
        Feature(
            symbol: "calendar.circle.fill", color: .mint, title: "Calendar Converter",
            text: "See any date in the Hebrew, Islamic, Chinese, Persian and other calendars, and count down to it every year.",
            destination: .calculator(.calendarConverter)
        ),
        Feature(
            symbol: "clock.fill", color: .blue, title: "Times in Calculators",
            text: "Time Between, Find a Date, Exact Age and Milestones take an optional time, down to the minute.",
            destination: .calculator(.timeBetween)
        ),
        Feature(
            symbol: "globe.europe.africa.fill", color: .cyan, title: "Time Zones, Clearer",
            text: "Change the time in any city, see who's at work, and find the best time to meet.",
            destination: .calculator(.timeZones)
        ),
        Feature(
            symbol: "bed.double.fill", color: .nightfall, title: "A Better Bedtime",
            text: "Plan from your wake-up time or your bedtime, with your own sleep cycle and a nightly reminder.",
            destination: .calculator(.sleep)
        ),
        Feature(
            symbol: "square.grid.2x2.fill", color: .purple, title: "New Widgets",
            text: "A Moon widget and complication, a large Countdown widget, and progress on your Home and Lock Screen."
        ),
        Feature(
            symbol: "chart.bar.fill", color: .orange, title: "Progress at a Glance",
            text: "Events with progress show it on their cards, and the event page says how many days are gone."
        ),
        Feature(
            symbol: "square.and.arrow.up.fill", color: .green, title: "Export and Import",
            text: "Keep every event as a backup or a spreadsheet, and bring them back any time.",
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
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityHidden(true)
                        Text("What's New in Timity")
                            .font(.largeTitle.weight(.bold))
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
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: 400)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
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
                    Button("Try It") {
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
