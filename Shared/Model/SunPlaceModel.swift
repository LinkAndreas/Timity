import Foundation
import Observation

/// The place the Sun screens show: the last one found, until the current one is.
@MainActor
@Observable
final class SunPlaceModel {
    enum Status: Equatable {
        case idle
        case locating
        case denied
        case failed
    }

    private(set) var status = Status.idle
    private(set) var place: Place?

    @ObservationIgnored private let locator: PlaceLocating
    @ObservationIgnored private let onLocate: (Place) -> Void

    /// - Parameters:
    ///   - place: The place found last time.
    ///   - onLocate: Called with every newly found place, e.g. to keep it for the widgets.
    init(place: Place?, locator: PlaceLocating, onLocate: @escaping (Place) -> Void) {
        self.place = place
        self.locator = locator
        self.onLocate = onLocate
    }

    var isAuthorized: Bool {
        locator.authorization == .authorized
    }

    /// Finds the current place, asking for permission the first time.
    func locate() async {
        guard status != .locating else { return }
        status = .locating
        do {
            let place = try await locator.locate()
            self.place = place
            status = .idle
            onLocate(place)
        } catch LocationError.denied {
            status = .denied
        } catch {
            status = .failed
        }
    }
}
