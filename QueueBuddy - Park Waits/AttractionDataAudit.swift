import Foundation

/// Compares the IDs StaticData ships against what Queue-Times actually
/// returns over time, so we can find out when our static catalog has
/// drifted from reality without manually auditing 150+ attractions.
///
/// Records on every successful park fetch, persists to UserDefaults, and
/// logs a one-shot report from `loadInitialData()`. Drift is only flagged
/// once an attraction has been missing (or an unknown ID consistently
/// present) for 7 days, so a single off day for the API doesn't alert.
enum AttractionDataAudit {
    private static let storageKey = "qb.attractionAudit.v1"
    private static let driftThreshold: TimeInterval = 7 * 24 * 60 * 60

    private struct State: Codable {
        var lastSeenInAPI: [Int: Date] = [:]
        var firstSeenUnknown: [Int: Date] = [:]
        var unknownNames: [Int: String] = [:]
        var lastSuccessfulFetchByPark: [Int: Date] = [:]
    }

    private static var cached: State?

    private static func load() -> State {
        if let cached { return cached }
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            cached = decoded
            return decoded
        }
        let fresh = State()
        cached = fresh
        return fresh
    }

    private static func save(_ state: State) {
        cached = state
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Records what the API returned for a park. No-op on empty responses
    /// or static-fallback rows (those carry status "N/A"); we only update
    /// timestamps when the data clearly came from Queue-Times.
    static func record(parkId: Int, liveAttractions: [Attraction], now: Date = Date()) {
        guard !liveAttractions.isEmpty else { return }
        let looksReal = liveAttractions.contains {
            $0.status == "Operating" || $0.status == "Closed"
        }
        guard looksReal else { return }

        var state = load()
        state.lastSuccessfulFetchByPark[parkId] = now

        let staticIds = Set(
            StaticData.getAttractionDetails()
                .filter { $0.value.parkId == parkId }
                .map { $0.key }
        )
        let liveIds = Set(liveAttractions.map { $0.id })

        for live in liveAttractions {
            state.lastSeenInAPI[live.id] = now
            if staticIds.contains(live.id) {
                // No longer "unknown" if we'd ever flagged it.
                state.firstSeenUnknown.removeValue(forKey: live.id)
                state.unknownNames.removeValue(forKey: live.id)
            } else {
                if state.firstSeenUnknown[live.id] == nil {
                    state.firstSeenUnknown[live.id] = now
                }
                state.unknownNames[live.id] = live.name
            }
        }

        // Forget unknown IDs the API stopped returning over a week ago, so
        // a one-off blip doesn't permanently inflate the report.
        for unknownId in Array(state.firstSeenUnknown.keys) where !liveIds.contains(unknownId) {
            if let lastSeen = state.lastSeenInAPI[unknownId],
               now.timeIntervalSince(lastSeen) > driftThreshold {
                state.firstSeenUnknown.removeValue(forKey: unknownId)
                state.unknownNames.removeValue(forKey: unknownId)
                state.lastSeenInAPI.removeValue(forKey: unknownId)
            }
        }

        save(state)
    }

    struct DriftReport {
        struct Item {
            let id: Int
            let name: String
            let parkId: Int?
            let lastSeen: Date?
            let firstSeen: Date?
        }

        var missingStatic: [Item] = []
        var unknownLive: [Item] = []
        var isEmpty: Bool { missingStatic.isEmpty && unknownLive.isEmpty }
    }

    /// Static IDs that haven't been returned by the API for 7+ days while
    /// other attractions in the same park have, plus unknown IDs the API
    /// has kept returning for 7+ days.
    static func report(now: Date = Date()) -> DriftReport {
        let state = load()
        var out = DriftReport()
        let allStatic = StaticData.getAttractionDetails()

        for (id, details) in allStatic {
            // We already know about overrides, so skip them.
            if StaticData.statusOverride(for: id) != nil { continue }
            guard let lastFetch = state.lastSuccessfulFetchByPark[details.parkId] else { continue }
            let lastSeen = state.lastSeenInAPI[id]
            let stale: Bool = {
                if let lastSeen { return lastFetch.timeIntervalSince(lastSeen) > driftThreshold }
                // Never seen, but we've fetched the park. Wait a week
                // before flagging in case the audit just started.
                return now.timeIntervalSince(lastFetch) > driftThreshold
            }()
            if stale {
                out.missingStatic.append(.init(
                    id: id,
                    name: details.name,
                    parkId: details.parkId,
                    lastSeen: lastSeen,
                    firstSeen: nil
                ))
            }
        }

        for (id, firstSeen) in state.firstSeenUnknown {
            guard now.timeIntervalSince(firstSeen) > driftThreshold else { continue }
            let name = state.unknownNames[id] ?? "Unknown"
            out.unknownLive.append(.init(
                id: id,
                name: name,
                parkId: nil,
                lastSeen: state.lastSeenInAPI[id],
                firstSeen: firstSeen
            ))
        }

        return out
    }

    /// Convenience: print the drift report to the console. No-op when
    /// there's nothing to flag, so an in-the-clear app stays quiet.
    static func logReport(now: Date = Date()) {
        let r = report(now: now)
        guard !r.isEmpty else { return }
        let formatter = ISO8601DateFormatter()
        dprint("Attraction data audit:")
        if !r.missingStatic.isEmpty {
            dprint("  Static IDs not returned by API for 7+ days (consider retiring):")
            for e in r.missingStatic.sorted(by: { ($0.parkId ?? 0) < ($1.parkId ?? 0) }) {
                let last = e.lastSeen.map { formatter.string(from: $0) } ?? "never"
                let park = e.parkId.map(String.init) ?? "?"
                dprint("    - \(e.id) \(e.name) (park \(park), last seen \(last))")
            }
        }
        if !r.unknownLive.isEmpty {
            dprint("  Live API IDs missing from StaticData (consider adding):")
            for e in r.unknownLive.sorted(by: { ($0.firstSeen ?? Date()) < ($1.firstSeen ?? Date()) }) {
                let first = e.firstSeen.map { formatter.string(from: $0) } ?? "?"
                dprint("    - \(e.id) \(e.name) - first seen \(first)")
            }
        }
    }
}
