import SwiftUI

/// Builds an object the first time the view appears and keeps it for as long as
/// the view stays in the hierarchy, so a screen's dependencies live and die with it.
///
///     WithState {
///         SunPlaceModel(place: nil, locator: CoreLocationPlaceLocator()) { _ in }
///     } content: { model in
///         SunView(location: model)
///     }
struct WithState<Object, Content: View>: View {
    private let build: () -> Object
    private let content: (Object) -> Content

    /// Holds the object. Recreating this box when a parent redraws is cheap and
    /// discarded; `@State` keeps the first one, so `build` runs once per view lifetime.
    @State private var box = WithStateBox<Object>()

    init(_ build: @escaping () -> Object, @ViewBuilder content: @escaping (Object) -> Content) {
        self.build = build
        self.content = content
    }

    var body: some View {
        content(box.object(build))
    }
}

/// Holds `WithState`'s object; apart from the view, so it depends on the object's type alone.
private final class WithStateBox<Object> {
    private var object: Object?

    func object(_ build: () -> Object) -> Object {
        if let object { return object }
        let built = build()
        object = built
        return built
    }
}
