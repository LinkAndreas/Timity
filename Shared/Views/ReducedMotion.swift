import SwiftUI

extension View {
    /// `transition(_:)` that becomes a plain fade with Reduce Motion, so nothing
    /// slides or zooms for readers who asked for less movement.
    func motionTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionTransition(transition: transition))
    }
}

private struct MotionTransition: ViewModifier {
    let transition: AnyTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}
