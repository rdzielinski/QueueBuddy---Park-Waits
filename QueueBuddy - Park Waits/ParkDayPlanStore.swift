import Foundation

struct ParkDayPlanItem: Identifiable, Codable, Hashable {
    let id: UUID
    let attractionId: Int
    let attractionName: String
    let parkId: Int
    let parkName: String
    var plannedDate: Date
    var note: String
    var isDone: Bool

    init(
        id: UUID = UUID(),
        attractionId: Int,
        attractionName: String,
        parkId: Int,
        parkName: String,
        plannedDate: Date = Date(),
        note: String = "",
        isDone: Bool = false
    ) {
        self.id = id
        self.attractionId = attractionId
        self.attractionName = attractionName
        self.parkId = parkId
        self.parkName = parkName
        self.plannedDate = plannedDate
        self.note = note
        self.isDone = isDone
    }
}

@MainActor
final class ParkDayPlanStore: ObservableObject {
    static let shared = ParkDayPlanStore()

    @Published private(set) var items: [ParkDayPlanItem] = []

    private let storageKey = "parkDayPlanItems-v1"

    private init() {
        load()
    }

    func items(for parkId: Int? = nil) -> [ParkDayPlanItem] {
        items
            .filter { parkId == nil || $0.parkId == parkId }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.plannedDate < $1.plannedDate
            }
    }

    func contains(attractionId: Int) -> Bool {
        items.contains { $0.attractionId == attractionId }
    }

    func add(attraction: Attraction, park: Park, note: String = "", plannedDate: Date = Date()) {
        guard !contains(attractionId: attraction.id) else { return }
        items.append(
            ParkDayPlanItem(
                attractionId: attraction.id,
                attractionName: attraction.name,
                parkId: park.id,
                parkName: park.name,
                plannedDate: plannedDate,
                note: note
            )
        )
        save()
    }

    func addTopPicks(from attractions: [Attraction], park: Park, limit: Int = 5) {
        let candidates = attractions
            .filter { $0.is_open == true }
            .filter { !contains(attractionId: $0.id) }
            .map { attraction in
                PlanCandidate(
                    attraction: attraction,
                    land: StaticData.attractionToLandMapping[attraction.id] ?? "Other",
                    score: planScore(for: attraction)
                )
            }
            .sorted {
                if $0.score != $1.score { return $0.score < $1.score }
                let leftWait = $0.attraction.wait_time ?? Int.max
                let rightWait = $1.attraction.wait_time ?? Int.max
                if leftWait != rightWait { return leftWait < rightWait }
                return $0.attraction.id < $1.attraction.id
            }

        let picks = routeBalancedPicks(from: candidates, limit: limit)
        let startDate = Date()
        for (index, candidate) in picks.enumerated() {
            let waitText = candidate.attraction.wait_time.map { "\($0)m" } ?? "open"
            add(
                attraction: candidate.attraction,
                park: park,
                note: "Smart pick - \(waitText) - \(candidate.land)",
                plannedDate: startDate.addingTimeInterval(Double(index) * 45 * 60)
            )
        }
    }

    private struct PlanCandidate {
        let attraction: Attraction
        let land: String
        let score: Int
    }

    private func routeBalancedPicks(from candidates: [PlanCandidate], limit: Int) -> [PlanCandidate] {
        var remaining = candidates
        var selected: [PlanCandidate] = []
        var landCounts: [String: Int] = [:]

        while selected.count < limit, !remaining.isEmpty {
            let previousLand = selected.last?.land
            let preferredIndex = remaining.firstIndex { candidate in
                candidate.land != previousLand && landCounts[candidate.land, default: 0] < 2
            } ?? remaining.indices.first!

            let candidate = remaining.remove(at: preferredIndex)
            selected.append(candidate)
            landCounts[candidate.land, default: 0] += 1
        }

        return selected
    }

    private func planScore(for attraction: Attraction) -> Int {
        let wait = attraction.wait_time ?? 75
        var score = wait

        if wait == 0 { score -= 8 }
        if wait <= 20 { score -= 6 }
        if wait > 60 { score += 20 }

        let type = attraction.type?.lowercased() ?? ""
        if StaticData.isLikelyIndoor(type: attraction.type) { score -= 4 }
        if type.contains("show") || type.contains("parade") || type.contains("character") { score += 18 }
        if type.contains("coaster") || type.contains("thrill") { score -= 3 }

        if let delta = WaitHistoryStore.shared.trendDelta(for: attraction.id) {
            if delta <= -10 { score -= 8 }
            if delta >= 10 { score += 10 }
        }

        return score
    }

    func toggleDone(_ item: ParkDayPlanItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        save()
    }

    func remove(_ item: ParkDayPlanItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearDone() {
        items.removeAll { $0.isDone }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ParkDayPlanItem].self, from: data) else { return }
        items = decoded
    }
}
