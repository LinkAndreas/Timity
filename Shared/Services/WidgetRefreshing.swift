import WidgetKit

/// The widgets that are refreshed on their own when what they show changes.
enum WidgetKind: String {
    case sun = "SunWidget"
    case lifeInWeeks = "LifeInWeeksWidget"
}

/// Asks the system to redraw widgets and complications.
protocol WidgetRefreshing: Sendable {
    func reloadAll()
    func reload(_ kind: WidgetKind)
}

struct WidgetKitRefresher: WidgetRefreshing {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reload(_ kind: WidgetKind) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind.rawValue)
    }
}
