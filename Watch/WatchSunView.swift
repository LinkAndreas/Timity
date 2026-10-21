import SwiftUI

/// Today's sunrise, golden hour and sunset on the Watch.
struct WatchSunView: View {
    let location: SunPlaceModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                if let place = location.place {
                    let sun = SolarCalculator.day(containing: context.date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
                    WatchSunRow(title: "common.sunrise", symbol: "sunrise.fill", date: sun.sunrise, tint: .orange)
                    WatchSunRow(title: "common.goldenHour", symbol: "camera.filters", date: sun.goldenHourEveningStart, tint: .yellow)
                    WatchSunRow(title: "common.sunset", symbol: "sunset.fill", date: sun.sunset, tint: .pink)
                    LabeledContent("common.daylight") {
                        Text(Duration.seconds(sun.daylight).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                } else if location.status == .denied {
                    Text("watch.allowTimityToUseYour")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("common.sun")
        .task { await location.locate() }
    }
}

/// A time of the day, or a dash on days without it.
private struct WatchSunRow: View {
    let title: LocalizedStringKey
    let symbol: String
    let date: Date?
    let tint: Color

    var body: some View {
        LabeledContent {
            Text(date?.formatted(date: .omitted, time: .shortened) ?? "—")
                .monospacedDigit()
        } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(tint)
        }
    }
}
