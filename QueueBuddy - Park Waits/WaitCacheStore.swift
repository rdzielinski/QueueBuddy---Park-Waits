import Foundation

/// Compact on-disk cache of the latest park and attraction waits. Shared
/// between the main app, the widget extension, the Apple Watch app, and
/// App Intents — whichever can read the App Group.
///
/// Uses UserDefaults under the App Group when the Suite is available, and
/// falls back to standard UserDefaults otherwise. Enable the App Group
/// entitlement (`group.Dzielinski.QueueBuddy`) on each target to unlock
/// sharing.
enum WaitCacheStore {
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

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(parks: [CachedPark], at date: Date = Date()) {
        guard let data = try? JSONEncoder().encode(parks) else { return }
        defaults.set(data, forKey: parksKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastSyncKey)
    }

    static func loadParks() -> [CachedPark] {
        guard let data = defaults.data(forKey: parksKey),
              let parks = try? JSONDecoder().decode([CachedPark].self, from: data) else {
            return []
        }
        return parks
    }

    static func loadPark(id: Int) -> CachedPark? {
        loadParks().first { $0.id == id }
    }

    static func loadAttraction(id: Int) -> (park: CachedPark, attraction: CachedAttraction)? {
        for park in loadParks() {
            if let attraction = park.attractions.first(where: { $0.id == id }) {
                return (park, attraction)
            }
        }
        return nil
    }

    static var lastSync: Date? {
        let ts = defaults.double(forKey: lastSyncKey)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }
}
