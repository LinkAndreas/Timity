import AppIntents

/// Hands the shared intents what they declare with `@Dependency`. The system
/// creates intents itself, so each process registers these once, at launch.
enum IntentDependencies {
    @MainActor
    static func register(
        repository: any EventRepository,
        reader: any EventReader,
        widgets: any WidgetRefreshing,
        sharedSettings: SharedSettings
    ) {
        AppDependencyManager.shared.add(dependency: repository)
        AppDependencyManager.shared.add(dependency: reader)
        AppDependencyManager.shared.add(dependency: widgets)
        AppDependencyManager.shared.add(dependency: sharedSettings)
    }
}
