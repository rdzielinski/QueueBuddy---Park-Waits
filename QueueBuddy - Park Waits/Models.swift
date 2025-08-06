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

// --- Gemini API Models ---
// FIXED: Removed the 'private' keyword from these structs, making them accessible
// to other files in the app, like ThemeParkAPI.swift.
struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}
struct GeminiCandidate: Decodable {
    let content: GeminiContent
}
struct GeminiContent: Decodable {
    let parts: [GeminiPart]
}
struct GeminiPart: Decodable {
    let text: String
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
