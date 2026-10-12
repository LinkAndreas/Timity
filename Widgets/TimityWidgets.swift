import SwiftUI
import WidgetKit

@main
struct TimityWidgets: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        UpcomingWidget()
        LifeInWeeksWidget()
        CountdownLiveActivity()
        NewEventControl()
    }
}
