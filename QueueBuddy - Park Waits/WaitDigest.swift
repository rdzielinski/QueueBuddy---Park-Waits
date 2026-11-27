import Foundation

/// Cross-park wait summary shared by the Plan chat and the Siri intents.
///
/// "What's the longest wait?" across several parks is a sorting problem,
/// not a reading-comprehension one: smaller models (Apple Intelligence in
/// particular) get it wrong when handed 300 raw lines. So the answer is
/// computed here and handed to the model, or spoken directly, as facts.
struct WaitDigest {
    struct Ride: Hashable {
        let name: String
        let parkId: Int
        let parkName: String
        let wait: Int?
        let isOpen: Bool
    }

    struct ParkStat {
        let parkId: Int
        let parkName: String
        let openCount: Int
        let totalCount: Int
        let averageWait: Int?
        let longest: Ride?
    }

    let rides: [Ride]
    let parkOrder: [(id: Int, name: String)]

    init(parks: [(id: Int, name: String)], rides: [Ride]) {
        self.parkOrder = parks
        self.rides = rides.filter { !$0.name.localizedCaseInsensitiveContains("single rider") }
    }

    /// Open rides reporting a wait.
    var timedRides: [Ride] { rides.filter { $0.isOpen && $0.wait != nil } }

    func longest(_ n: Int) -> [Ride] {
        Array(timedRides.sorted { ($0.wait ?? 0, $1.name) > ($1.wait ?? 0, $0.name) }.prefix(n))
    }

    func shortest(_ n: Int) -> [Ride] {
        Array(timedRides.sorted { ($0.wait ?? 0, $0.name) < ($1.wait ?? 0, $1.name) }.prefix(n))
    }

    var parkStats: [ParkStat] {
        parkOrder.map { park in
            let mine = rides.filter { $0.parkId == park.id }
            let timed = mine.filter { $0.isOpen && $0.wait != nil }
            let waits = timed.compactMap(\.wait)
            return ParkStat(
                parkId: park.id,
                parkName: park.name,
                openCount: mine.filter(\.isOpen).count,
                totalCount: mine.count,
                averageWait: waits.isEmpty ? nil : waits.reduce(0, +) / waits.count,
                longest: timed.max { ($0.wait ?? 0) < ($1.wait ?? 0) }
            )
        }
    }

    var hasLiveWaits: Bool { !timedRides.isEmpty }

    static func waitText(_ minutes: Int) -> String {
        minutes == 0 ? "walk-on" : "\(minutes) min"
    }

    /// Precomputed facts for the model's context: leaderboards and per-park
    /// averages across every park in scope.
    func factsBlock(top n: Int = 8) -> String {
        let names = parkOrder.map(\.name).joined(separator: ", ")
        var s = "LIVE WAIT FACTS across \(names) (already sorted — use these for longest/shortest/which-park questions):"
        s += "\n\nLONGEST WAITS"
        for r in longest(n) { s += "\n  - \(r.name) (\(r.parkName)): \(Self.waitText(r.wait ?? 0))" }
        s += "\n\nSHORTEST WAITS"
        for r in shortest(n) { s += "\n  - \(r.name) (\(r.parkName)): \(Self.waitText(r.wait ?? 0))" }
        s += "\n\nBY PARK"
        for p in parkStats {
            var line = "\n  - \(p.parkName): \(p.openCount) of \(p.totalCount) open"
            if let avg = p.averageWait { line += ", average wait \(avg) min" }
            if let top = p.longest, let w = top.wait { line += ", longest \(top.name) at \(w) min" }
            s += line
        }
        if !hasLiveWaits { s += "\n\n(No live waits are being reported right now — the parks may be closed.)" }
        return s
    }

    /// One compact line per open ride, grouped by park. Used for multi-park
    /// context on cloud models; skipped for the small on-device model.
    func rosterBlock() -> String {
        var s = "ALL ATTRACTIONS IN SCOPE (the complete list — do not mention anything else):"
        for park in parkOrder {
            let mine = rides.filter { $0.parkId == park.id }.sorted { $0.name < $1.name }
            guard !mine.isEmpty else { continue }
            s += "\n\n" + park.name.uppercased()
            for r in mine {
                let status = !r.isOpen ? "closed" : r.wait.map(Self.waitText) ?? "wait unknown"
                s += "\n  - \(r.name): \(status)"
            }
        }
        return s
    }
}

// MARK: - Sources

extension WaitDigest {
    /// From the shared cache the widget and intents read.
    static func fromCache(parkIds: Set<Int>?) -> WaitDigest {
        let parks = WaitCacheStore.loadParks().filter { parkIds?.contains($0.id) ?? true }
        return fromCached(parks)
    }

    static func fromCached(_ parks: [WaitCacheStore.CachedPark]) -> WaitDigest {
        WaitDigest(
            parks: parks.map { ($0.id, $0.name) },
            rides: parks.flatMap { park in
                park.attractions.map {
                    Ride(name: $0.name, parkId: park.id, parkName: park.name,
                         wait: $0.waitMinutes, isOpen: $0.isOpen)
                }
            }
        )
    }

    /// From live app state.
    static func from(parks: [Park], attractionsByPark: [Int: [Attraction]]) -> WaitDigest {
        WaitDigest(
            parks: parks.map { ($0.id, $0.name) },
            rides: parks.flatMap { park in
                (attractionsByPark[park.id] ?? []).map {
                    Ride(name: $0.name, parkId: park.id, parkName: park.name,
                         wait: $0.wait_time, isOpen: $0.is_open ?? true)
                }
            }
        )
    }
}
