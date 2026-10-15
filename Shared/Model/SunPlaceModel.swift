import Foundation
import Observation

/// The place the Sun screens show: where the user is, or a place they chose,
/// such as a holiday destination or where family lives.
@MainActor
@Observable
final class SunPlaceModel {
    enum Status: Equatable {
        case idle
        case locating
        case denied
        case failed
    }

    /// The places the user saved, and whether the screen follows their location.
    struct Choices: Equatable {
        var saved: [Place] = []
        var followsLocation = true
    }

    private(set) var status = Status.idle
    private(set) var place: Place?
    private(set) var choices: Choices

    @ObservationIgnored private let locator: PlaceLocating
    @ObservationIgnored private let onPlace: (Place) -> Void
    @ObservationIgnored private let onChoices: (Choices) -> Void

    /// - Parameters:
    ///   - place: The place shown last time.
    ///   - onPlace: Called with every place shown, e.g. to keep it for the widgets.
    ///   - onChoices: Called when places are saved, removed or chosen.
    init(
        place: Place?,
        choices: Choices = Choices(),
        locator: PlaceLocating,
        onChoices: @escaping (Choices) -> Void = { _ in },
        onPlace: @escaping (Place) -> Void
    ) {
        self.place = place
        self.choices = choices
        self.locator = locator
        self.onChoices = onChoices
        self.onPlace = onPlace
    }

    var isAuthorized: Bool {
        locator.authorization == .authorized
    }

    var followsLocation: Bool { choices.followsLocation }
    var savedPlaces: [Place] { choices.saved }

    /// Follows the user's location again and finds it, asking for permission the first time.
    func useCurrentLocation() async {
        if !choices.followsLocation {
            choices.followsLocation = true
            onChoices(choices)
        }
        await locate()
    }

    /// Finds the current place, if the screen follows the user's location.
    func locate() async {
        guard choices.followsLocation, status != .locating else { return }
        status = .locating
        do {
            let place = try await locator.locate()
            guard choices.followsLocation else { return status = .idle }
            show(place)
            status = .idle
        } catch LocationError.denied {
            status = .denied
        } catch {
            status = .failed
        }
    }

    /// Shows a saved or found place, and keeps it among the saved ones.
    func choose(_ place: Place) {
        if !choices.saved.contains(where: { $0.isSameSpot(as: place) }) {
            choices.saved.append(place)
        }
        choices.followsLocation = false
        status = .idle
        onChoices(choices)
        show(place)
    }

    func remove(_ place: Place) {
        choices.saved.removeAll { $0.isSameSpot(as: place) }
        onChoices(choices)
    }

    private func show(_ place: Place) {
        self.place = place
        onPlace(place)
    }
}

nonisolated extension Place {
    /// Within about a kilometre: the same city, however it was found.
    func isSameSpot(as other: Place) -> Bool {
        abs(latitude - other.latitude) < 0.01 && abs(longitude - other.longitude) < 0.01
    }
}
