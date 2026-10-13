import MapKit

/// Finds places by name, such as "Lisbon" or "Sydney".
@MainActor
protocol PlaceSearching {
    func places(matching query: String) async -> [Place]
}

/// Cities and regions from Apple Maps, each in its own time zone.
struct MapKitPlaceSearch: PlaceSearching {
    func places(matching query: String) async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        guard let items = try? await MKLocalSearch(request: request).start().mapItems else { return [] }
        return items.compactMap { item in
            let coordinate = item.location.coordinate
            let city = item.addressRepresentations?.cityName ?? item.name
            guard let city else { return nil }
            let region = item.addressRepresentations?.regionName
            return Place(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZoneIdentifier: (item.timeZone ?? .autoupdatingCurrent).identifier,
                name: city,
                detail: region
            )
        }
    }
}
