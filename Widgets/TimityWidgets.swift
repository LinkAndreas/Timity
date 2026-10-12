import SwiftUI
import WidgetKit

@main
struct TimityWidgets: WidgetBundle {
    @MainActor
    init() {
        WidgetComposition.registerIntentDependencies()
    }

    var body: some Widget {
        CountdownWidget()
        UpcomingWidget()
        TimeLeftWidget()
        SunWidget()
        LifeInWeeksWidget()
        CountdownLiveActivity()
        NewEventControl()
    }
}
