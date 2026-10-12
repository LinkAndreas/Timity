import CoreLocation
import WidgetKit
import MapKit
import Observation

/// The place the Sun tab shows: the current location when allowed, remembered
/// between launches, with its name and time zone.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle
        case locating
        case denied
        case failed
    }

    struct Place: Equatable {
        var latitude: Double
        var longitude: Double
        var name: String?
        var timeZone: TimeZone
    }

    private(set) var status: Status = .idle
    private(set) var place: Place?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        place = Self.restore(from: defaults)
    }

    /// Finds the current location, asking for permission the first time.
    func locate() {
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .locating
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        default:
            status = .locating
            manager.requestLocation()
        }
    }

    var isAuthorized: Bool {
        [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        Task { @MainActor in
            switch authorization {
            case .authorizedWhenInUse, .authorizedAlways:
                if status == .locating || place == nil {
                    status = .locating
                    self.manager.requestLocation()
                }
            case .denied, .restricted:
                status = .denied
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in await apply(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Couldn't find the location: \(error)")
            status = .failed
        }
    }

    // MARK: Private

    private func apply(_ location: CLLocation) async {
        var place = Place(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: nil,
            timeZone: .autoupdatingCurrent
        )
        // The place's own time zone, so the times are right for where the user is.
        if let request = MKReverseGeocodingRequest(location: location),
           let item = try? await request.mapItems.first {
            place.name = item.name
            place.timeZone = item.timeZone ?? .autoupdatingCurrent
        }
        self.place = place
        status = .idle
        save(place)
    }

    private func save(_ place: Place) {
        // The same key Timity 3 used, so its last location carries over.
        defaults.set(["latitude": place.latitude, "longitude": place.longitude], forKey: "lastLocation")
        defaults.set(place.name, forKey: "lastLocationName")
        defaults.set(place.timeZone.identifier, forKey: "lastLocationTimeZone")
        // The Sun widgets read it from the app group.
        SharedSettings.place = SharedSettings.Place(
            latitude: place.latitude,
            longitude: place.longitude,
            timeZoneIdentifier: place.timeZone.identifier,
            name: place.name
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "SunWidget")
    }

    private static func restore(from defaults: UserDefaults) -> Place? {
        guard
            let coordinate = defaults.dictionary(forKey: "lastLocation") as? [String: Double],
            let latitude = coordinate["latitude"],
            let longitude = coordinate["longitude"]
        else { return nil }
        return Place(
            latitude: latitude,
            longitude: longitude,
            name: defaults.string(forKey: "lastLocationName"),
            timeZone: defaults.string(forKey: "lastLocationTimeZone").flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
        )
    }
}
