import SwiftUI

/// Today's sunrise, golden hour and sunset on the Watch.
struct WatchSunView: View {
    let location: SunPlaceModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                if let place = location.place {
                    let sun = SolarCalculator.day(containing: context.date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
                    row("common.sunrise", "sunrise.fill", sun.sunrise, .orange)
                    row("common.goldenHour", "camera.filters", sun.goldenHourEveningStart, .yellow)
                    row("common.sunset", "sunset.fill", sun.sunset, .pink)
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

    private func row(_ title: LocalizedStringKey, _ symbol: String, _ date: Date?, _ tint: Color) -> some View {
        LabeledContent {
            Text(date?.formatted(date: .omitted, time: .shortened) ?? "—")
                .monospacedDigit()
        } label: {
            Label(title, systemImage: symbol)
                .foregroundStyle(tint)
        }
    }
}
