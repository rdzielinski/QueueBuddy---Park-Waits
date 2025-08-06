import Foundation
import CoreLocation

struct TrackedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    var attractionName: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D, timestamp: Date, attractionName: String? = nil) {
        self.id = UUID()
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.attractionName = attractionName
    }

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, timestamp, attractionName
    }

    static func == (lhs: TrackedLocation, rhs: TrackedLocation) -> Bool {
        return lhs.id == rhs.id &&
            lhs.latitude == rhs.latitude &&
            lhs.longitude == rhs.longitude &&
            lhs.timestamp == rhs.timestamp &&
            lhs.attractionName == rhs.attractionName
    }
}

extension TrackedLocation {
    /// Returns a new TrackedLocation with the attractionName set to the closest attraction within 100 meters, if any.
    func matchedToAttraction(_ attractions: [Attraction]) -> TrackedLocation {
        guard let closest = attractions
            .compactMap({ attraction -> (attraction: Attraction, distance: CLLocationDistance)? in
                guard let lat = attraction.latitude, let lon = attraction.longitude else { return nil }
                let attractionCoord = CLLocation(latitude: lat, longitude: lon)
                let loc = CLLocation(latitude: self.latitude, longitude: self.longitude)
                return (attraction, loc.distance(from: attractionCoord))
            })
            .min(by: { $0.distance < $1.distance }), closest.distance < 100 else {
            return self
        }
        var copy = self
        copy.attractionName = closest.attraction.name
        return copy
    }
}
