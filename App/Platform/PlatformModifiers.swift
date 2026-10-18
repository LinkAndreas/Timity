import SwiftUI

/// Modifiers and placements that mean the same on iPhone, iPad and Mac, each done the
/// way the platform does it, so views read the same everywhere.
extension View {
    /// A small title in the bar, as for sheets and detail pages; the Mac's window title is always small.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// The keyboard for numbers and punctuation, where there's an on-screen keyboard.
    func numbersAndPunctuationKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }

    /// The keyboard for whole numbers, where there's an on-screen keyboard.
    func numberPadKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// The keyboard for decimal numbers, where there's an on-screen keyboard.
    func decimalPadKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Sections close together, as for cards that bring their own room.
    func compactSectionSpacing() -> some View {
        #if os(iOS)
        listSectionSpacing(.compact)
        #else
        self
        #endif
    }

    /// Hides the tab bar, e.g. while picking events; the Mac has none.
    func tabBarHidden(_ isHidden: Bool) -> some View {
        #if os(iOS)
        toolbarVisibility(isHidden ? .hidden : .automatic, for: .tabBar)
        #else
        self
        #endif
    }

    /// Deleting a row from its context menu on the Mac, where rows can't be swiped
    /// with a mouse; iPhone and iPad keep swiping.
    func macDeleteMenu(isEnabled: Bool = true, _ delete: @escaping () -> Void) -> some View {
        #if os(macOS)
        contextMenu {
            if isEnabled {
                Button("common.delete", systemImage: "trash", role: .destructive, action: delete)
            }
        }
        #else
        self
        #endif
    }

    /// A sheet's size on the Mac, which otherwise fits it tightly around its content;
    /// iPhone and iPad size sheets themselves.
    func macSheetSize(width: CGFloat = 520, height: CGFloat = 620) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height)
        #else
        self
        #endif
    }

    /// A screen over everything on iPhone and iPad, a sheet on the Mac.
    func fullScreen<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #endif
    }

    /// Search under the title on iPhone and iPad, shown by pulling down; in the toolbar on the Mac.
    func pullDownSearchable(text: Binding<String>, prompt: LocalizedStringKey, alwaysShown: Bool = false) -> some View {
        #if os(iOS)
        searchable(text: text, placement: .navigationBarDrawer(displayMode: alwaysShown ? .always : .automatic), prompt: prompt)
        #else
        searchable(text: text, placement: .toolbar, prompt: prompt)
        #endif
    }
}

extension ToolbarItemPlacement {
    /// The trailing end of the navigation bar, or of the window's toolbar on the Mac.
    static var trailingBar: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }

    /// Along the bottom on iPhone and iPad; the Mac keeps actions in the window's toolbar.
    static var bottomActions: ToolbarItemPlacement {
        #if os(iOS)
        .bottomBar
        #else
        .automatic
        #endif
    }
}
