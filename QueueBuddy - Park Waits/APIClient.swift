// ThemeParkAPI.swift

import Foundation

/// Feature flags for incremental rollout of the ThemeParks.wiki backend.
/// Each park ID listed here will fetch from `api.themeparks.wiki` first
/// and fall back to queue-times.com on failure. All other parks continue
/// to fetch directly from queue-times.
enum FeatureFlags {
    /// Park IDs that should attempt ThemeParks.wiki before queue-times.
    /// All 7 supported parks are on the rollout — Magic Kingdom shipped
    /// first and we've validated parity for the rest. Override at
    /// runtime via the user-defaults key `qb.themeparkswiki.enabledParks`
    /// (comma-separated int list, or empty string to disable).
    static var useThemeParksWikiForParks: Set<Int> {
        let defaults: Set<Int> = [5, 6, 7, 8, 64, 65, 334]
        guard let raw = UserDefaults.standard.string(forKey: "qb.themeparkswiki.enabledParks") else {
            return defaults
        }
        // Empty-string override disables ThemeParks.wiki entirely (forces
        // every park back onto queue-times). Useful for emergency rollback.
        if raw.trimmingCharacters(in: .whitespaces).isEmpty { return [] }
        let overrides = raw.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return overrides.isEmpty ? defaults : Set(overrides)
    }
}

class ThemeParkAPI {
    static let shared = ThemeParkAPI()

    private let queueTimesBaseURL = URL(string: "https://queue-times.com")!
    private let themeParksWiki = ThemeParksWikiClient.shared
    private var lastWeatherFetch: [Int: Date] = [:] // parkId : last fetch date

    private init() {}

    func fetchResortGroups() async throws -> [ResortGroup] {
        return StaticData.buildResortGroups()
    }

    func fetchWaitTimes(for parkId: Int) async throws -> [Attraction] {
        // Route through ThemeParks.wiki when the park is in the rollout set;
        // any error falls through to the queue-times path below so we never
        // strand the user on a 404 / decoding bump from the new backend.
        if FeatureFlags.useThemeParksWikiForParks.contains(parkId) {
            do {
                let attractions = try await themeParksWiki.fetchWaitTimes(forParkId: parkId)
                if !attractions.isEmpty {
                    dprint("✅ ThemeParks.wiki returned \(attractions.count) attractions for park \(parkId)")
                    return attractions
                }
                dprint("⚠️ ThemeParks.wiki returned empty list for park \(parkId), falling back to queue-times")
            } catch {
                dprint("⚠️ ThemeParks.wiki failed for park \(parkId): \(error). Falling back to queue-times.")
            }
        }
        return try await fetchWaitTimesFromQueueTimes(for: parkId)
    }

    /// Fetch today's operating schedule for a park (open/close, Early Entry,
    /// Lightning Lane prices). Only available for parks routed through
    /// ThemeParks.wiki — returns nil for parks still on queue-times since
    /// queue-times doesn't expose schedules in a structured form.
    func fetchSchedule(for parkId: Int) async -> ParkSchedule? {
        guard FeatureFlags.useThemeParksWikiForParks.contains(parkId) else { return nil }
        do {
            return try await themeParksWiki.fetchSchedule(forParkId: parkId)
        } catch {
            dprint("⚠️ ThemeParks.wiki schedule failed for park \(parkId): \(error)")
            return nil
        }
    }

    private func fetchWaitTimesFromQueueTimes(for parkId: Int) async throws -> [Attraction] {
        let url = queueTimesBaseURL.appendingPathComponent("parks/\(parkId)/queue_times.json")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        dprint("✅ Fetching REAL wait times from: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "No error body"
                dprint("❌ Invalid response from wait time server for park ID \(parkId). Error: \(errorString)")
                return StaticData.getStaticAttractions(for: parkId)
            }
            let liveResponse = try JSONDecoder().decode(LiveParkDataResponse.self, from: data)
            let allLiveAttractions = liveResponse.lands.flatMap { $0.rides } + liveResponse.rides
            if allLiveAttractions.isEmpty {
                dprint("⚠️ Live API returned no attractions for park ID \(parkId). Falling back to static data.")
                return StaticData.getStaticAttractions(for: parkId)
            }
            return allLiveAttractions.map { Attraction(id: $0.id, name: $0.name, wait_time: $0.wait_time, status: $0.is_open ? "Operating" : "Closed", is_open: $0.is_open) }
        } catch {
            dprint("❗️ Network request for live data failed for park ID \(parkId). Error: \(error.localizedDescription). Retrying once after delay...")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errorString = String(data: data, encoding: .utf8) ?? "No error body"
                    dprint("❌ Second attempt failed for park ID \(parkId). Error: \(errorString)")
                    return StaticData.getStaticAttractions(for: parkId)
                }
                let liveResponse = try JSONDecoder().decode(LiveParkDataResponse.self, from: data)
                let allLiveAttractions = liveResponse.lands.flatMap { $0.rides } + liveResponse.rides
                if allLiveAttractions.isEmpty {
                    dprint("⚠️ Second attempt: Live API returned no attractions for park ID \(parkId). Falling back to static data.")
                    return StaticData.getStaticAttractions(for: parkId)
                }
                return allLiveAttractions.map { Attraction(id: $0.id, name: $0.name, wait_time: $0.wait_time, status: $0.is_open ? "Operating" : "Closed", is_open: $0.is_open) }
            } catch {
                dprint("❗️ Second network request for live data failed for park ID \(parkId). Error: \(error.localizedDescription). Falling back to static data.")
                return StaticData.getStaticAttractions(for: parkId)
            }
        }
    }

    // MARK: - Open-Meteo Weather API

    func fetchWeatherForecast(for parkId: Int) async throws -> WeatherForecast? {
        // Rate limit: only fetch if 10 minutes have passed since last fetch for this park
        if let lastFetch = lastWeatherFetch[parkId], Date().timeIntervalSince(lastFetch) < 600 {
            dprint("⏳ Weather for park \(parkId) fetched less than 10 minutes ago. Skipping API call.")
            return nil
        }

        guard let coords = StaticData.parkCoordinates[parkId] else {
            dprint("❌ No coordinates found for park ID \(parkId)")
            return nil
        }

        // Open-Meteo API: No API key required
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coords.lat)&longitude=\(coords.lon)&current=temperature_2m,weathercode,wind_speed_10m&temperature_unit=fahrenheit"
        guard let url = URL(string: urlString) else {
            dprint("❌ Invalid Open-Meteo weather URL.")
            return nil
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "No error body"
            dprint("Open-Meteo API error: \(errorString)")
            return nil
        }

        let apiResponse = try JSONDecoder().decode(OpenMeteoWeatherResponse.self, from: data)
        guard let current = apiResponse.current else {
            dprint("No current weather data in Open-Meteo response.")
            return nil
        }

        let appForecast = WeatherForecast(
            temperature: current.temperature_2m,
            description: OpenMeteoWeatherResponse.weatherDescription(for: current.weathercode),
            icon: OpenMeteoWeatherResponse.weatherIcon(for: current.weathercode)
        )
        lastWeatherFetch[parkId] = Date()
        return appForecast
    }
}

// MARK: - Open-Meteo Response Models

struct OpenMeteoWeatherResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weathercode: Int
        let wind_speed_10m: Double
    }
    let current: Current?

    // Map Open-Meteo weather codes to descriptions/icons
    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }
    static func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "01d"
        case 1, 2, 3: return "02d"
        case 45, 48: return "50d"
        case 51, 53, 55: return "09d"
        case 56, 57: return "13d"
        case 61, 63, 65: return "10d"
        case 66, 67: return "13d"
        case 71, 73, 75: return "13d"
        case 77: return "13d"
        case 80, 81, 82: return "09d"
        case 85, 86: return "13d"
        case 95: return "11d"
        case 96, 99: return "11d"
        default: return "01d"
        }
    }
}
