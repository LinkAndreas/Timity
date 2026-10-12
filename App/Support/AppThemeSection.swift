import SwiftUI
import UIKit

/// The app icons with their themes. Supporters pick the icon Timity shows on the
/// Home Screen, and the app takes on its colour; everyone else sees them locked, as
/// a preview of what recurring support includes.
struct AppThemeSection: View {
    let isUnlocked: Bool

    @Environment(AppSettings.self) private var settings
    /// Goes up with every tap on a locked icon, to bounce its lock.
    @State private var lockedTapCount = 0

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeTile(
                            theme: theme,
                            isSelected: theme == settings.theme,
                            isLocked: !isUnlocked && theme.isSupporterTheme,
                            lockedTapCount: lockedTapCount
                        ) {
                            select(theme)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: settings.theme)
            .sensoryFeedback(.impact(weight: .light), trigger: lockedTapCount)
        } header: {
            Text("App Icon & Theme")
        } footer: {
            Text(isUnlocked
                ? LocalizedStringKey("Thanks for your support! Pick an icon for your Home Screen — Timity takes on its colour.")
                : LocalizedStringKey("Recurring support unlocks six app icons, each with a matching theme, for as long as it’s active."))
        }
    }

    private func select(_ theme: AppTheme) {
        guard isUnlocked || !theme.isSupporterTheme else {
            lockedTapCount += 1
            return
        }
        guard theme != settings.theme else { return }

        let previous = settings.theme
        withAnimation { settings.theme = theme }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(theme.alternateIconName)
            } catch {
                logger.error("Failed to set the app icon to \(theme.rawValue): \(error)")
                withAnimation { settings.theme = previous }
            }
        }
    }
}

/// One icon in the picker: its preview, its name, and a ring when it's chosen.
private struct ThemeTile: View {
    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool
    let lockedTapCount: Int
    let action: () -> Void

    private static let size: CGFloat = 64
    /// The Home Screen's corner shape, scaled to the preview.
    private static let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(theme.previewImageName)
                    .resizable()
                    .frame(width: Self.size, height: Self.size)
                    .clipShape(Self.shape)
                    .overlay {
                        Self.shape.strokeBorder(.separator, lineWidth: 0.5)
                    }
                    .padding(4)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Self.size * 0.225 + 4, style: .continuous)
                                .strokeBorder(theme.accentColor.color, lineWidth: 2.5)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.black.opacity(0.55), in: .circle)
                                .symbolEffect(.bounce, value: lockedTapCount)
                        }
                    }

                Text(theme.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        // Plain, so each icon is its own button rather than the whole row.
        .buttonStyle(.plain)
        .accessibilityLabel(Text(theme.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isLocked ? Text("Included with recurring support") : Text(verbatim: ""))
    }
}
