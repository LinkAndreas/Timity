import WidgetKit

/// The widgets that are refreshed on their own when what they show changes.
nonisolated enum WidgetKind: String {
    case sun = "SunWidget"
    case lifeInWeeks = "LifeInWeeksWidget"
}

/// Asks the system to redraw widgets and complications.
nonisolated protocol WidgetRefreshing: Sendable {
    func reloadAll()
    func reload(_ kind: WidgetKind)
}

nonisolated struct WidgetKitRefresher: WidgetRefreshing {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reload(_ kind: WidgetKind) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
    }
}
