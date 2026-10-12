import CoreLocation
import SwiftUI
import WidgetKit

/// Today's sunrise, golden hour and sunset on the Watch. Finding the location here
/// also gives the Sun complication its place.
struct WatchSunView: View {
    @State private var location = WatchLocation()

    var body: some View {
        TimelineView(.everyMinute) { context in
            List {
                if let place = location.place {
                    let sun = SolarCalculator.day(containing: context.date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
                    row("Sunrise", "sunrise.fill", sun.sunrise, .orange)
                    row("Golden Hour", "camera.filters", sun.goldenHourEveningStart, .yellow)
                    row("Sunset", "sunset.fill", sun.sunset, .pink)
                    LabeledContent("Daylight") {
                        Text(Duration.seconds(sun.daylight).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                } else if location.isDenied {
                    Text("Allow Timity to use your location in the Watch's Settings to see sunrise and sunset.")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Sun")
        .task { location.locate() }
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

/// The Watch's location, kept for the Sun complication.
@MainActor
@Observable
final class WatchLocation: NSObject, CLLocationManagerDelegate {
    private(set) var place = SharedSettings.place
    private(set) var isDenied = false

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locate() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: isDenied = true
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: isDenied = true
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            let place = SharedSettings.Place(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier,
                name: nil
            )
            self.place = place
            SharedSettings.place = place
            WidgetCenter.shared.reloadTimelines(ofKind: "SunWidget")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
