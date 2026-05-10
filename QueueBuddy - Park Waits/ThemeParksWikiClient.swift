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
    private let isoDecoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        let dec = JSONDecoder()
        // ThemeParks.wiki timestamps are ISO 8601 with timezone offset, sometimes
        // with fractional seconds. .iso8601 chokes on the fractional variant, so
        // we use a custom strategy that tolerates both.
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = Self.isoFormatter.date(from: raw)
                ?? Self.isoFormatterFractional.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        self.isoDecoder = dec
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    enum ClientError: Error {
        case unknownPark(Int)
        case http(Int)
        case decoding(Error)
    }

    // MARK: - Live waits

    /// Fetch live attractions for one of our internal int parkIds. Throws
    /// when the park isn't in `parkUUIDByInternalId` or the network call
    /// fails — callers can catch and fall back to queue-times.
    func fetchWaitTimes(forParkId parkId: Int) async throws -> [Attraction] {
        guard let uuid = StaticData.parkUUIDByInternalId[parkId] else {
            throw ClientError.unknownPark(parkId)
        }
        let decoded: TPWLiveResponse = try await get(path: "entity/\(uuid)/live")

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
                case "OPERATING":     return "Operating"
                case "CLOSED":        return "Closed"
                case "DOWN":          return "Down"
                case "REFURBISHMENT": return "Refurbishment"
                case let other?:      return other.capitalized
                case nil:             return "Unknown"
                }
            }()

            // First operating window of the day is "today's window". If
            // multiple are reported (rare), take the earliest start.
            let todayWindow = entity.operatingHours?
                .filter { $0.type.uppercased() == "OPERATING" }
                .sorted { $0.startTime < $1.startTime }
                .first

            let forecastPoints: [ForecastPoint]? = entity.forecast?
                .map { ForecastPoint(time: $0.time, waitMinutes: $0.waitTime, percentage: $0.percentage) }
                .sorted { $0.time < $1.time }

            let returnTime: ReturnTimeState? = {
                guard let rt = entity.queue?.RETURN_TIME, let state = rt.state else { return nil }
                guard let parsed = ReturnTimeState.State(rawValue: state.uppercased()) else { return nil }
                return ReturnTimeState(
                    state: parsed,
                    returnStart: rt.returnStart,
                    returnEnd: rt.returnEnd
                )
            }()

            attractions.append(Attraction(
                id: internalId,
                name: entity.name,
                wait_time: waitMinutes,
                status: statusLabel,
                is_open: isOpen,
                last_updated: entity.lastUpdated.map { Self.isoFormatter.string(from: $0) } ?? nowISO,
                forecast: forecastPoints,
                operatingStart: todayWindow?.startTime,
                operatingEnd: todayWindow?.endTime,
                returnTime: returnTime
            ))
        }
        return attractions
    }

    // MARK: - Park schedule (hours + Lightning Lane purchases)

    /// Fetch today's operating schedule for the park: open/close window,
    /// any Early Entry ticketed event, and today's Lightning Lane purchase
    /// options with live availability + pricing.
    func fetchSchedule(forParkId parkId: Int) async throws -> ParkSchedule {
        guard let uuid = StaticData.parkUUIDByInternalId[parkId] else {
            throw ClientError.unknownPark(parkId)
        }
        let decoded: TPWScheduleResponse = try await get(path: "entity/\(uuid)/schedule")

        // The API returns entries for the next ~30 days. We only care
        // about today's date in the park's local timezone.
        let timezone = TimeZone(identifier: decoded.timezone ?? "") ?? .current
        let todayString: String = {
            let f = DateFormatter()
            f.timeZone = timezone
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let todayEntries = decoded.schedule.filter { $0.date == todayString }

        let operating = todayEntries
            .first(where: { $0.type.uppercased() == "OPERATING" })
            .map { entry in
                ScheduleEntry(
                    date: entry.date,
                    openingTime: entry.openingTime,
                    closingTime: entry.closingTime,
                    type: entry.type,
                    description: entry.description
                )
            }

        let earlyEntry = todayEntries
            .first(where: { entry in
                entry.type.uppercased() == "TICKETED_EVENT" &&
                (entry.description?.lowercased().contains("early") ?? false)
            })
            .map { entry in
                ScheduleEntry(
                    date: entry.date,
                    openingTime: entry.openingTime,
                    closingTime: entry.closingTime,
                    type: entry.type,
                    description: entry.description
                )
            }

        // Lightning Lane purchases come in under the OPERATING entry's
        // `purchases` array. Dedupe by id in case the API repeats them.
        let ll: [LightningLanePurchase] = todayEntries
            .flatMap { $0.purchases ?? [] }
            .map { p in
                LightningLanePurchase(
                    id: p.id,
                    name: p.name,
                    priceFormatted: p.price?.formatted,
                    priceCents: p.price?.amount,
                    available: p.available
                )
            }
            .reduce(into: [LightningLanePurchase]()) { acc, item in
                if !acc.contains(where: { $0.id == item.id }) { acc.append(item) }
            }

        return ParkSchedule(
            parkId: parkId,
            timezone: decoded.timezone,
            today: operating,
            earlyEntry: earlyEntry,
            lightningLane: ll
        )
    }

    // MARK: - HTTP

    private func get<T: Decodable>(path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("QueueBuddy/iOS", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ClientError.http(http.statusCode)
        }
        do {
            return try isoDecoder.decode(T.self, from: data)
        } catch {
            throw ClientError.decoding(error)
        }
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
    let operatingHours: [TPWOperatingHours]?
    let forecast: [TPWForecast]?
    let lastUpdated: Date?
}

private struct TPWQueue: Decodable {
    let STANDBY: TPWStandby?
    let RETURN_TIME: TPWReturnTime?
}

private struct TPWStandby: Decodable {
    let waitTime: Int?
}

private struct TPWReturnTime: Decodable {
    let state: String?
    let returnStart: Date?
    let returnEnd: Date?
}

private struct TPWOperatingHours: Decodable {
    let type: String
    let startTime: Date
    let endTime: Date
}

private struct TPWForecast: Decodable {
    let time: Date
    let waitTime: Int
    let percentage: Int
}

private struct TPWScheduleResponse: Decodable {
    let timezone: String?
    let schedule: [TPWScheduleEntry]
}

private struct TPWScheduleEntry: Decodable {
    let date: String
    let type: String
    let openingTime: Date
    let closingTime: Date
    let description: String?
    let purchases: [TPWPurchase]?
}

private struct TPWPurchase: Decodable {
    let id: String
    let name: String
    let type: String?
    let price: TPWPrice?
    let available: Bool
}

private struct TPWPrice: Decodable {
    let amount: Int?
    let currency: String?
    let formatted: String?
}
