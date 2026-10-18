import SwiftUI

/// Support the Developer as a sheet, opened from Settings.
struct SupportSheet<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(String(localized: "common.supportTheDeveloper"))
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        // The system close button: an ✕ with the localized "Close" label.
                        Button(role: .close) { dismiss() }
                    }
                }
        }
        // A centred form on iPad rather than a full-height page.
        .presentationSizing(.form)
    }
}

#if DEBUG
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SupportSheet {
                SupportView(store: SupportStore(service: PreviewSupportService())) { _ in EmptyView() }
            }
        }
}
#endif
