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

    func trendDelta(for attractionId: Int) -> Int? {
        let list = history(for: attractionId)
        guard let current = list.last?.minutes else { return nil }
        let hourAgo = Date().addingTimeInterval(-3600)
        guard let pastSample = list.reversed().first(where: { $0.at <= hourAgo }) else { return nil }
        return current - pastSample.minutes
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
}
