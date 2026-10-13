import CoreLocation
import MapKit

/// Names the place another locator finds after its city, in its own time zone,
/// so times are right for where the user is.
@MainActor
final class GeocodingPlaceLocator: PlaceLocating {
    private let base: PlaceLocating

    init(_ base: PlaceLocating) {
        self.base = base
    }

    var authorization: LocationAuthorization { base.authorization }

    func locate() async throws -> Place {
        var place = try await base.locate()
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        if let request = MKReverseGeocodingRequest(location: location),
           let item = try? await request.mapItems.first {
            // The city, not the street the user happens to stand in.
            place.name = item.addressRepresentations?.cityName ?? item.name
            place.timeZoneIdentifier = (item.timeZone ?? .autoupdatingCurrent).identifier
        }
        return place
    }
}
