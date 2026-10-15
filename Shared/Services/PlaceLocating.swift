import CoreLocation
import Foundation

nonisolated enum LocationAuthorization {
    case notDetermined, denied, authorized
}

nonisolated enum LocationError: Error {
    case denied
    case failed
}

/// Finds the place the device is at.
@MainActor
protocol PlaceLocating: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Finds the current place, asking for permission the first time.
    /// - Throws: `LocationError`.
    func locate() async throws -> Place
}

/// The device's place from Core Location, roughly to the kilometre, in the
/// device's own time zone and without a name.
@MainActor
final class CoreLocationPlaceLocator: NSObject, PlaceLocating, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: LocationAuthorization {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        default: .denied
        }
    }

    func locate() async throws -> Place {
        if authorization == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        guard authorization == .authorized else { throw LocationError.denied }

        let location = try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
        return Place(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard authorization != .notDetermined else { return }
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Couldn't find the location: \(error)")
            locationContinuation?.resume(throwing: LocationError.failed)
            locationContinuation = nil
        }
    }
}
