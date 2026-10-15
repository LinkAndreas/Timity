import SwiftUI

/// A heart and a short note on why support is welcome, at the top of Support the Developer.
struct SupportHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.circle.fill")
                .scaledFont(size: 52)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.pink)
                .accessibilityHidden(true)
            Text(String(localized: "support.supportTimity"))
                .font(.title2.bold())
            Text(String(localized: "support.timityIsFreeWithNo"))
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
