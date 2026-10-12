import SwiftUI

/// A heart and a short note on why support is welcome, at the top of Support the Developer.
struct SupportHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.pink)
                .accessibilityHidden(true)
            Text(String(localized: "Support Timity"))
                .font(.title2.bold())
            Text(String(localized: "Timity is free, with no ads and every feature included. If it’s useful to you, you can support its maintenance and the development of new features — recurring supporters get six app icons, each with a matching theme, as a thank-you."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    SupportHeader()
        .padding()
}
#endif
