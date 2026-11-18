import SwiftUI

/// The app icons, for everyone to pick the one Timity shows on the Home Screen, or in
/// the Dock on the Mac. The tint is chosen separately, under Appearance.
struct AppThemeSection: View {
    @Binding var theme: AppTheme
    /// Changes the Home Screen icon; `nil` for the main one.
    let setAppIcon: (_ alternateIconName: String?) async throws -> Void

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(AppTheme.allCases) { candidate in
                        ThemeTile(theme: candidate, isSelected: candidate == theme) {
                            select(candidate)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .sensoryFeedback(.selection, trigger: theme)
        } header: {
            Text("settings.appIcon")
        } footer: {
            Text(LocalizedStringKey(Platform.appIconNoteKey))
        }
    }

    private func select(_ chosen: AppTheme) {
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

#if DEBUG
#Preview {
    Form {
        AppThemeSection(theme: .constant(.lagoon)) { _ in }
    }
}
#endif
