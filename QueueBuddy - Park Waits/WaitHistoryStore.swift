import Foundation

/// Rolling local history of wait-time samples per attraction. Each app refresh
/// appends one sample and we keep up to the last ~24 hours. Backed by
/// UserDefaults for simplicity — the dataset is tiny.
@MainActor
final class WaitHistoryStore: ObservableObject {
    static let shared = WaitHistoryStore()

    struct Sample: Codable, Hashable {
        let at: Date
        let minutes: Int
    }

    private let storageKey = "waitHistorySamples-v1"
    private let maxAgeHours: Double = 24
    private let maxSamplesPerRide: Int = 144 // ~every 10 min for 24h

    @Published private(set) var samples: [Int: [Sample]] = [:]

    /// In-memory cache of extended history pulled from the worker
    /// (`WaitHistoryClient`). Keyed by attractionId then range; never
    /// persisted to disk — the worker is the source of truth for
    /// anything beyond 24h, and the cache exists only to avoid
    /// re-hitting it on every chart redraw.
    @Published private(set) var extendedSamples: [Int: [WaitHistoryClient.Range: [Sample]]] = [:]
    private var extendedFetchedAt: [Int: [WaitHistoryClient.Range: Date]] = [:]
    /// How long an extended fetch stays fresh. Server samples every 5
    /// minutes, so refetching faster than that is a waste.
    private let extendedCacheTTL: TimeInterval = 5 * 60

    init() {
        load()
    }

    func record(attractionId: Int, minutes: Int, at date: Date = Date()) {
        var list = samples[attractionId, default: []]
        list.append(Sample(at: date, minutes: minutes))
        // Trim by age and count.
        let cutoff = date.addingTimeInterval(-maxAgeHours * 3600)
        list.removeAll { $0.at < cutoff }
        if list.count > maxSamplesPerRide {
            list.removeFirst(list.count - maxSamplesPerRide)
        }
        samples[attractionId] = list
        save()
    }

    /// All samples for an attraction, oldest first.
    func history(for attractionId: Int) -> [Sample] {
        samples[attractionId, default: []]
    }

    /// History over an arbitrary range. 24h is served from the on-device
    /// ring buffer (no network); 7d/30d fetch from the Cloudflare worker's
    /// D1-backed `/history` endpoint and cache the result in memory for
    /// the next ~5 minutes.
    func extendedHistory(
        for attractionId: Int,
        attractionName: String,
        range: WaitHistoryClient.Range
    ) async -> [Sample] {
        if range == .day {
            return history(for: attractionId)
        }
        if let cached = cachedExtended(attractionId: attractionId, range: range) {
            return cached
        }
        let remote = await WaitHistoryClient.fetchHistory(attractionName: attractionName, range: range)
        // Drop samples with nil minutes — sparkline can't render closed
        // periods as a numeric value, and our existing Sample type doesn't
        // support nil. Status-aware charting can come later.
        let mapped: [Sample] = remote.compactMap { r in
            guard let m = r.wait else { return nil }
            return Sample(at: Date(timeIntervalSince1970: TimeInterval(r.at)), minutes: m)
        }
        cacheExtended(mapped, attractionId: attractionId, range: range)
        return mapped
    }

    private func cachedExtended(
        attractionId: Int, range: WaitHistoryClient.Range
    ) -> [Sample]? {
        guard let fetched = extendedFetchedAt[attractionId]?[range],
              Date().timeIntervalSince(fetched) < extendedCacheTTL,
              let cached = extendedSamples[attractionId]?[range] else { return nil }
        return cached
    }

    private func cacheExtended(
        _ samples: [Sample], attractionId: Int, range: WaitHistoryClient.Range
    ) {
        var byRange = extendedSamples[attractionId] ?? [:]
        byRange[range] = samples
        extendedSamples[attractionId] = byRange
        var tsByRange = extendedFetchedAt[attractionId] ?? [:]
        tsByRange[range] = Date()
        extendedFetchedAt[attractionId] = tsByRange
    }

    func trendDelta(for attractionId: Int) -> Int? {
        let list = history(for: attractionId)
        guard let current = list.last?.minutes else { return nil }
        let hourAgo = Date().addingTimeInterval(-3600)
        guard let pastSample = list.reversed().first(where: { $0.at <= hourAgo }) else { return nil }
        return current - pastSample.minutes
    }

    /// Short-term trend direction based on last two samples.
    func recentTrend(for attractionId: Int) -> Int? {
        let list = history(for: attractionId)
        guard list.count >= 2 else { return nil }
        let current = list[list.count - 1].minutes
        let previous = list[list.count - 2].minutes
        return current - previous
    }

    /// Average wait across all tracked attractions for a given park.
    func crowdLevel(parkAttractionIds: [Int]) -> CrowdLevel? {
        let recentWaits = parkAttractionIds.compactMap { samples[$0]?.last?.minutes }
        guard !recentWaits.isEmpty else { return nil }
        let avg = recentWaits.reduce(0, +) / recentWaits.count
        return CrowdLevel.from(averageWait: avg)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let dict = try? JSONDecoder().decode([Int: [Sample]].self, from: data) else { return }
        samples = dict
    }

    func clearAll() {
        samples = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
