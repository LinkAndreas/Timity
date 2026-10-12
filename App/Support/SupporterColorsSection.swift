import SwiftUI

/// The supporter colours. Supporters can use them for events, widgets and the
/// app's tint; everyone else sees them locked, as a preview of what recurring
/// support includes.
struct SupporterColorsSection: View {
    let isUnlocked: Bool

    @Environment(AppSettings.self) private var settings
    /// Goes up with every tap on a locked colour, to bounce its lock.
    @State private var lockedTapCount = 0

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(EventColor.supporterColors) { color in
                        Button {
                            if isUnlocked {
                                withAnimation { settings.accentColor = color }
                            } else {
                                lockedTapCount += 1
                            }
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(color.gradient)
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        if !isUnlocked {
                                            Image(systemName: "lock.fill")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .symbolEffect(.bounce, value: lockedTapCount)
                                        } else if settings.accentColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text(color.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(color.name))
                        .accessibilityAddTraits(settings.accentColor == color ? .isSelected : [])
                        .accessibilityHint(isUnlocked ? Text("Uses the colour for the app") : Text("Included with recurring support"))
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: settings.accentColor)
            .sensoryFeedback(.impact(weight: .light), trigger: lockedTapCount)
        } header: {
            Text("Supporter Colours")
        } footer: {
            Text(isUnlocked
                ? LocalizedStringKey("Thanks for your support! Tap a colour to tint Timity with it, or pick one for any event.")
                : LocalizedStringKey("Recurring support unlocks these six colours for events, widgets and the app for as long as it’s active."))
        }
    }
}
