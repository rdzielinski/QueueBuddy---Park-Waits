import Foundation
import CoreLocation
import Combine

/// Lightweight location manager used for one thing: figure out which park
/// (if any) the user is currently inside, so the app can auto-open it.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var nearestPark: Park?
    @Published private(set) var isInsidePark: Bool = false

    /// Radius (in meters) from a park's coordinate to consider the user "at" it.
    private let parkRadius: CLLocationDistance = 1600

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    /// Kick off a one-shot location request after requesting permission if needed.
    func requestNearestPark() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    /// Return the park whose coordinate is within `parkRadius` of `location`, if any.
    func nearestPark(to location: CLLocation) -> (park: Park, distance: CLLocationDistance)? {
        let groups = StaticData.buildResortGroups()
        let candidates: [(Park, CLLocationDistance)] = groups
            .flatMap { $0.parks }
            .compactMap { park in
                guard let coords = StaticData.parkCoordinates[park.id] else { return nil }
                let parkLoc = CLLocation(latitude: coords.lat, longitude: coords.lon)
                return (park, location.distance(from: parkLoc))
            }
        guard let closest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return closest.1 <= parkRadius ? closest : nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            if let result = self.nearestPark(to: loc) {
                self.nearestPark = result.park
                self.isInsidePark = true
            } else {
                self.nearestPark = nil
                self.isInsidePark = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }
}
