import SwiftUI
import WidgetKit

@main
struct TimityWatchWidgets: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        UpcomingWidget()
        TimeLeftWidget()
        SunWidget()
    }
}
