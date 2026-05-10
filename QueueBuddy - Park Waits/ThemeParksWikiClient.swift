import Foundation

/// Client for the public ThemeParks.wiki v1 HTTP API
/// (`https://api.themeparks.wiki/v1`). Free, no auth, returns the same
/// destinations parksapi exposes plus richer per-attraction data: live
/// status, queue waits, hourly forecast, per-ride operating windows,
/// Lightning Lane / virtual queue state, and show times.
///
/// Returned `[Attraction]` matches the existing queue-times shape so the
/// rest of the app stays unchanged. Attractions whose names don't match
/// our static catalog are dropped — favorites, notifications, lands, and
/// sparklines all key off the int IDs in `StaticData`, so a synthesized
/// ID would only be partially functional.
final class ThemeParksWikiClient {
    static let shared = ThemeParksWikiClient()

    private let baseURL = URL(string: "https://api.themeparks.wiki/v1")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    enum ClientError: Error {
        case unknownPark(Int)
        case http(Int)
        case decoding(Error)
    }

    /// Fetch live attractions for one of our internal int parkIds. Throws
    /// when the park isn't in `parkUUIDByInternalId` or the network call
    /// fails — callers can catch and fall back to queue-times.
    func fetchWaitTimes(forParkId parkId: Int) async throws -> [Attraction] {
        guard let uuid = StaticData.parkUUIDByInternalId[parkId] else {
            throw ClientError.unknownPark(parkId)
        }
        let url = baseURL
            .appendingPathComponent("entity")
            .appendingPathComponent(uuid)
            .appendingPathComponent("live")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QueueBuddy/iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ClientError.http(http.statusCode)
        }

        let decoded: TPWLiveResponse
        do {
            decoded = try JSONDecoder().decode(TPWLiveResponse.self, from: data)
        } catch {
            throw ClientError.decoding(error)
        }

        var attractions: [Attraction] = []
        attractions.reserveCapacity(decoded.liveData.count)
        let nowISO = ISO8601DateFormatter().string(from: Date())

        for entity in decoded.liveData where entity.entityType == "ATTRACTION" {
            // Resolve to our internal int ID so favorites/notifications/lands
            // continue to work. Skip if we don't know this attraction yet —
            // surfacing it with a synthetic ID would only be half-functional.
            guard let internalId = StaticData.internalAttractionId(forName: entity.name) else {
                #if DEBUG
                print("⚠️ ThemeParks.wiki attraction not in static catalog, skipping: \(entity.name)")
                #endif
                continue
            }
            let waitMinutes = entity.queue?.STANDBY?.waitTime
            let isOpen = (entity.status?.uppercased() == "OPERATING")
            let statusLabel: String = {
                switch entity.status?.uppercased() {
                case "OPERATING": return "Operating"
                case "CLOSED":    return "Closed"
                case "DOWN":      return "Down"
                case "REFURBISHMENT": return "Refurbishment"
                case let other?: return other.capitalized
                case nil: return "Unknown"
                }
            }()

            attractions.append(Attraction(
                id: internalId,
                name: entity.name,
                wait_time: waitMinutes,
                status: statusLabel,
                is_open: isOpen,
                last_updated: entity.lastUpdated ?? nowISO
            ))
        }
        return attractions
    }
}

// MARK: - ThemeParks.wiki decoding models

private struct TPWLiveResponse: Decodable {
    let liveData: [TPWLiveEntity]
}

private struct TPWLiveEntity: Decodable {
    let id: String
    let name: String
    let entityType: String
    let status: String?
    let queue: TPWQueue?
    let lastUpdated: String?
}

private struct TPWQueue: Decodable {
    let STANDBY: TPWStandby?
}

private struct TPWStandby: Decodable {
    let waitTime: Int?
}
