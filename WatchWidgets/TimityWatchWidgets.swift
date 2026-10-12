import SwiftUI
import WidgetKit

@main
struct TimityWatchWidgets: WidgetBundle {
    @MainActor
    init() {
        WidgetComposition.registerIntentDependencies()
    }

    var body: some Widget {
        CountdownWidget()
        UpcomingWidget()
        TimeLeftWidget()
        SunWidget()
    }
}
