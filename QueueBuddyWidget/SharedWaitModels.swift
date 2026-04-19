import Foundation
import SwiftUI

/// Mirror of `WaitCacheStore` for the widget/watch targets.
/// Keep these types in sync with the main app's `WaitCacheStore`.
enum WaitCacheReader {
    static let suiteName = "group.Dzielinski.QueueBuddy"
    static let lastSyncKey = "qb.lastSync"
    static let parksKey = "qb.parks"

    struct CachedPark: Codable, Hashable, Identifiable {
        let id: Int
        let name: String
        let accentHex: UInt32
        let openCount: Int
        let totalCount: Int
        let avgWait: Int?
        let attractions: [CachedAttraction]
    }

    struct CachedAttraction: Codable, Hashable, Identifiable {
        let id: Int
        let name: String
        let waitMinutes: Int?
        let isOpen: Bool
        let minHeightInches: Int?
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    static func loadParks() -> [CachedPark] {
        guard let data = defaults.data(forKey: parksKey),
              let parks = try? JSONDecoder().decode([CachedPark].self, from: data) else { return [] }
        return parks
    }

    static var lastSync: Date? {
        let ts = defaults.double(forKey: lastSyncKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func loadFavoriteAttractions(limit: Int = 4) -> [(park: CachedPark, attraction: CachedAttraction)] {
        let favoritesData = UserDefaults.standard.data(forKey: "favorites")
        let favorites: Set<Int> = favoritesData
            .flatMap { try? JSONDecoder().decode(Set<Int>.self, from: $0) }
            ?? []

        var pairs: [(CachedPark, CachedAttraction)] = []
        for park in loadParks() {
            for attraction in park.attractions where favorites.contains(attraction.id) {
                pairs.append((park, attraction))
            }
        }
        pairs.sort { ($0.1.waitMinutes ?? Int.max) < ($1.1.waitMinutes ?? Int.max) }
        return Array(pairs.prefix(limit))
    }
}

enum WidgetTheme {
    static let bg      = Color(red: 10/255,  green: 11/255,  blue: 13/255)
    static let card    = Color(red: 20/255,  green: 21/255,  blue: 25/255)
    static let card2   = Color(red: 27/255,  green: 29/255,  blue: 34/255)
    static let text    = Color(red: 244/255, green: 243/255, blue: 238/255)
    static let muted   = Color(red: 244/255, green: 243/255, blue: 238/255).opacity(0.55)
    static let dim     = Color(red: 244/255, green: 243/255, blue: 238/255).opacity(0.35)
    static let amber   = Color(red: 255/255, green: 181/255, blue: 71/255)
    static let green   = Color(red: 127/255, green: 212/255, blue: 160/255)
    static let red     = Color(red: 255/255, green: 107/255, blue: 107/255)

    static func tone(for wait: Int?) -> Color {
        guard let wait else { return amber }
        switch wait {
        case ...15: return green
        case ...45: return amber
        default:    return red
        }
    }

    static func color(fromHex hex: UInt32) -> Color {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
