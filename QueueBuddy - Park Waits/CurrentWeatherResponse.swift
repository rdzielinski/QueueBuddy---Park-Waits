// CurrentWeatherResponse.swift
// Model for decoding OpenWeatherMap current weather API response

import Foundation

public struct CurrentWeatherResponse: Decodable {
    public let weather: [Weather]
    public let main: Main
    public let rain: Rain?
    
    public struct Weather: Decodable {
        public let main: String
        public let description: String
        public let icon: String?
    }
    public struct Main: Decodable {
        public let temp: Double
    }
    public struct Rain: Decodable {
        public let oneHour: Double?
        
        enum CodingKeys: String, CodingKey {
            case oneHour = "1h"
        }
    }
}
