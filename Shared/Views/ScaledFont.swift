import SwiftUI

/// A system font at a set size that still follows the reader's text size, as the
/// text styles do. Big numbers grow less than body text, at most `maxScale` times,
/// so they keep fitting on screen; they shrink with smaller text sizes as well.
private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let baseSize: CGFloat
    private let weight: Font.Weight?
    private let design: Font.Design?
    private let maxScale: CGFloat

    init(size: CGFloat, weight: Font.Weight?, design: Font.Design?, relativeTo style: Font.TextStyle, maxScale: CGFloat) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        baseSize = size
        self.weight = weight
        self.design = design
        self.maxScale = maxScale
    }

    func body(content: Content) -> some View {
        content.font(.system(size: min(size, baseSize * maxScale), weight: weight, design: design))
    }
}

extension View {
    /// `.font(.system(size:weight:design:))` that grows with Dynamic Type.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil,
        relativeTo style: Font.TextStyle = .largeTitle,
        maxScale: CGFloat = 1.5
    ) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design, relativeTo: style, maxScale: maxScale))
    }
}
