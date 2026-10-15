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
        SunWidget()
        MoonWidget()
        CountdownLiveActivity()
        NewEventControl()
    }
}
