import SwiftUI

extension EnvironmentValues {
    /// Whether content sits on the event's photo rather than its colour, so text
    /// and glass need more to stand out from a busy background.
    @Entry var isOverPhoto = false
}

extension View {
    /// A soft shadow behind white text on a photo, so it reads on bright patches too.
    func legibleOverPhoto() -> some View {
        modifier(LegibleOverPhoto())
    }

    /// Glass that's tinted darker on a photo, so what's on it doesn't blend into the picture.
    func heroGlass<S: Shape>(in shape: S) -> some View {
        modifier(HeroGlass(shape: shape))
    }
}

private struct LegibleOverPhoto: ViewModifier {
    @Environment(\.isOverPhoto) private var isOverPhoto

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(isOverPhoto ? 0.55 : 0), radius: isOverPhoto ? 6 : 0, y: 1)
    }
}

private struct HeroGlass<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.isOverPhoto) private var isOverPhoto

    func body(content: Content) -> some View {
        content.glassEffect(isOverPhoto ? .regular.tint(.black.opacity(0.35)) : .regular, in: shape)
    }
}
