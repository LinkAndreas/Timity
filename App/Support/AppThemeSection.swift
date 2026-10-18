import SwiftUI

/// The alternate app icons. Supporters pick the icon Timity shows on the Home
/// Screen; everyone else sees them locked, as a preview of what recurring support
/// includes. The tint is chosen separately in Settings, by everyone.
struct AppThemeSection: View {
    let isUnlocked: Bool
    @Binding var theme: AppTheme
    /// Changes the Home Screen icon; `nil` for the main one.
    let setAppIcon: (_ alternateIconName: String?) async throws -> Void

    /// Goes up with every tap on a locked icon, to bounce its lock.
    @State private var lockedTapCount = 0

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(AppTheme.allCases) { candidate in
                        ThemeTile(
                            theme: candidate,
                            isSelected: candidate == theme,
                            isLocked: !isUnlocked && candidate.isSupporterTheme,
                            lockedTapCount: lockedTapCount
                        ) {
                            select(candidate)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: theme)
            .sensoryFeedback(.impact(weight: .light), trigger: lockedTapCount)
        } header: {
            Text("support.appIcon")
        } footer: {
            Text(isUnlocked
                ? LocalizedStringKey(Platform.thanksForSupportPickKey)
                : LocalizedStringKey("support.recurringSupportUnlocksSixAlternative"))
        }
    }

    private func select(_ chosen: AppTheme) {
        guard isUnlocked || !chosen.isSupporterTheme else {
            lockedTapCount += 1
            return
        }
        guard chosen != theme else { return }

        let previous = theme
        withAnimation { theme = chosen }
        Task {
            do {
                try await setAppIcon(chosen.alternateIconName)
            } catch {
                logger.error("Failed to set the app icon to \(chosen.rawValue): \(error)")
                withAnimation { theme = previous }
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
        .accessibilityHint(isLocked ? Text("support.includedWithRecurringSupport") : Text(verbatim: ""))
    }
}
