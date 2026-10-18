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
        #if os(iOS)
        // Live Activities are an iPhone feature.
        CountdownLiveActivity()
        #endif
        NewEventControl()
    }
}
