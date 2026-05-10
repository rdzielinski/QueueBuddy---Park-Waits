import Foundation
import SwiftUI
import CoreLocation

// MARK: - App's Internal Weather Model
public struct WeatherForecast: Identifiable {
    public let id = UUID()
    let temperature: Double
    let description: String
    let icon: String
    
    var iconURL: URL? {
        return URL(string: "https://openweathermap.org/img/wn/\(icon)@2x.png")
    }
}

// MARK: - Live API Decoding Models

// --- OpenWeatherMap One Call API v3 Models ---
struct OpenWeatherAPIResponse: Decodable {
    let current: CurrentWeather
}
struct CurrentWeather: Decodable {
    let temp: Double
    let weather: [WeatherDetails]
}
struct WeatherDetails: Decodable {
    let description: String
    let icon: String
}

// --- Queue-Times API Models ---
struct LiveParkDataResponse: Decodable {
    let lands: [LiveLand]
    let rides: [LiveAttraction]
}
struct LiveLand: Decodable {
    let id: Int
    let name: String
    let rides: [LiveAttraction]
}
struct LiveAttraction: Decodable {
    let id: Int
    let name: String
    let wait_time: Int
    let is_open: Bool
}

// MARK: - App's Core Data Models
struct Park: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
}
struct ResortGroup: Identifiable {
    let id = UUID()
    let name: String
    let parks: [Park]
}

public struct Attraction: Identifiable, Hashable {
    public let id: Int
    public var name: String
    public var wait_time: Int?
    public var status: String?
    public var is_open: Bool?
    public var last_updated: String?
    public var type: String?
    public var description: String?
    public var min_height_inches: Int?
    public var latitude: Double?
    public var longitude: Double?

    public var waitTimeDisplay: String {
        guard is_open == true else { return "Closed" }
        if let time = wait_time { return time == 0 ? "Walk-on" : "\(time) min" }
        return "N/A"
    }
    public var comparableWaitTime: Int {
        guard is_open == true else { return Int.max }
        return wait_time ?? (Int.max - 1)
    }
    init(id: Int, name: String, wait_time: Int?, status: String?, is_open: Bool?, last_updated: String? = nil, type: String? = nil, description: String? = nil, min_height_inches: Int? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id; self.name = name; self.wait_time = wait_time; self.status = status; self.is_open = is_open; self.last_updated = last_updated; self.type = type; self.description = description; self.min_height_inches = min_height_inches; self.latitude = latitude; self.longitude = longitude
    }
}

// MARK: - UI & State Models

struct LandDisplayGroup: Identifiable {
    let id = UUID()
    let name: String
    var attractions: [Attraction]
}

enum AttractionFilter: String, CaseIterable, Identifiable {
    case all = "All", operating = "Open", shortWait = "< 20m", moderateWait = "20-60m", longWait = "> 60m"
    var id: String { self.rawValue }
}

enum AttractionTypeFilter: String, CaseIterable, Identifiable {
    case all = "All Types"
    case coaster = "Coasters"
    case darkride = "Dark Rides"
    case water = "Water Rides"
    case show = "Shows"
    case spinner = "Spinners"
    case simulator = "Simulators"
    case meet = "Characters"
    case shooter = "Shooters"
    case experience = "Experiences"
    var id: String { rawValue }

    func matches(_ type: String?) -> Bool {
        if self == .all { return true }
        guard let type = type?.lowercased() else { return false }
        switch self {
        case .all: return true
        case .coaster: return type == "coaster"
        case .darkride: return type == "darkride"
        case .water: return type == "water" || type == "boat"
        case .show: return type == "show"
        case .spinner: return type == "spinner" || type == "carousel"
        case .simulator: return type == "simulator"
        case .meet: return type == "meet"
        case .shooter: return type == "shooter"
        case .experience: return type == "experience" || type == "train" || type == "car"
        }
    }
}

enum CrowdLevel: Int, CaseIterable {
    case low = 1, moderate = 2, busy = 3, packed = 4

    var label: String {
        switch self {
        case .low: return "LOW"
        case .moderate: return "MODERATE"
        case .busy: return "BUSY"
        case .packed: return "PACKED"
        }
    }

    var symbol: String {
        switch self {
        case .low: return "person"
        case .moderate: return "person.2"
        case .busy: return "person.3"
        case .packed: return "person.3.fill"
        }
    }

    static func from(averageWait: Int) -> CrowdLevel {
        switch averageWait {
        case ...10: return .low
        case ...25: return .moderate
        case ...45: return .busy
        default: return .packed
        }
    }
}

enum AttractionSort: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A-Z)", waitTimeAsc = "Wait (Shortest)", waitTimeDesc = "Wait (Longest)"
    var id: String { self.rawValue }
}

struct NotificationPreference: Identifiable, Codable, Hashable {
    let id: Int
    let attractionName: String
    let thresholdMinutes: Int
}

struct Event: Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let type: EventType
    let location: String
    let times: [Date]
    
    var nextUpcomingTime: Date? {
        times.sorted().first { $0 > Date() }
    }
}

enum EventType: String, CaseIterable, Identifiable, Codable {
    case show, parade, fireworks, characterGreeting, other
    var id: String { self.rawValue.capitalized }

    var symbol: String {
        switch self {
        case .show: return "music.mic.fill"
        case .parade: return "figure.roll"
        case .fireworks: return "sparkles"
        case .characterGreeting: return "face.smiling.fill"
        case .other: return "info.circle.fill"
        }
    }
}

// MARK: - Fuzzy Search

enum FuzzySearch {
    /// Returns a score 0…1 for how well `query` matches `target`.
    /// 1.0 = exact prefix, 0.0 = no match. Returns nil below threshold.
    static func score(_ query: String, against target: String, threshold: Double = 0.3) -> Double? {
        let q = query.lowercased()
        let t = target.lowercased()

        if t.hasPrefix(q) { return 1.0 }
        if t.contains(q) { return 0.9 }

        // Subsequence match: all chars of query appear in order
        var qi = q.startIndex
        for ch in t {
            if qi < q.endIndex && ch == q[qi] {
                qi = q.index(after: qi)
            }
        }
        if qi == q.endIndex {
            let ratio = Double(q.count) / Double(t.count)
            let score = 0.5 + ratio * 0.3
            return score >= threshold ? score : nil
        }

        // Edit distance fallback for short queries (typo tolerance)
        if q.count >= 3 && q.count <= t.count + 2 {
            let dist = editDistance(q, t.prefix(min(t.count, q.count + 4)))
            let maxLen = max(q.count, min(t.count, q.count + 4))
            let score = 1.0 - Double(dist) / Double(maxLen)
            return score >= threshold ? score * 0.7 : nil
        }

        return nil
    }

    private static func editDistance<S1: StringProtocol, S2: StringProtocol>(_ s1: S1, _ s2: S2) -> Int {
        let n = s2.count
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)
        for (i, c1) in s1.enumerated() {
            curr[0] = i + 1
            for (j, c2) in s2.enumerated() {
                curr[j + 1] = c1 == c2
                    ? prev[j]
                    : 1 + min(prev[j], prev[j + 1], curr[j])
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }
}
