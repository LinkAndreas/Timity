import AppIntents
import SwiftUI
import WidgetKit

/// A Control Center and Lock Screen button that opens Timity with a new event.
struct NewEventControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "de.link.timity.newEvent") {
            ControlWidgetButton(action: NewEventIntent()) {
                Label("New Event", systemImage: "calendar.badge.plus")
            }
        }
        .displayName("New Event")
        .description("Adds an event in Timity.")
    }
}
