import AppIntents
import Foundation

// MARK: - Entity

/// An attraction exposed to Shortcuts / Siri / Spotlight.
struct AttractionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Attraction")
    }

    static var defaultQuery = AttractionQuery()

    let id: Int
    let name: String
    let parkName: String
    let waitMinutes: Int?
    let isOpen: Bool

    var displayRepresentation: DisplayRepresentation {
        let subtitle: String
        if !isOpen {
            subtitle = "\(parkName) · Closed"
        } else if let w = waitMinutes {
            subtitle = "\(parkName) · \(w == 0 ? "Walk-on" : "\(w) min")"
        } else {
            subtitle = parkName
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(subtitle)")
    }
}

struct ParkEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Park")
    }
    static var defaultQuery = ParkQuery()

    let id: Int
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ParkQuery: EntityStringQuery {
    /// Lets Siri resolve a spoken park name ("Epic Universe", "Hollywood
    /// Studios") to a park.
    func entities(matching string: String) async throws -> [ParkEntity] {
        let needle = string.lowercased()
        return WaitCacheStore.loadParks()
            .filter { park in
                let name = park.name.lowercased()
                return name.contains(needle) || needle.contains(name)
                    || needle.split(separator: " ").filter { $0.count > 3 }.contains { name.contains($0) }
            }
            .map { ParkEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [Int]) async throws -> [ParkEntity] {
        WaitCacheStore.loadParks()
            .filter { identifiers.contains($0.id) }
            .map { ParkEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ParkEntity] {
        WaitCacheStore.loadParks().map { ParkEntity(id: $0.id, name: $0.name) }
    }
}

struct AttractionQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [AttractionEntity] {
        let parks = WaitCacheStore.loadParks()
        var result: [AttractionEntity] = []
        for id in identifiers {
            for park in parks {
                if let a = park.attractions.first(where: { $0.id == id }) {
                    result.append(AttractionEntity(
                        id: a.id,
                        name: a.name,
                        parkName: park.name,
                        waitMinutes: a.waitMinutes,
                        isOpen: a.isOpen
                    ))
                }
            }
        }
        return result
    }

    func suggestedEntities() async throws -> [AttractionEntity] {
        let parks = WaitCacheStore.loadParks()
        return parks.flatMap { park in
            park.attractions.prefix(8).map { a in
                AttractionEntity(
                    id: a.id,
                    name: a.name,
                    parkName: park.name,
                    waitMinutes: a.waitMinutes,
                    isOpen: a.isOpen
                )
            }
        }
    }
}

// MARK: - Intent: check wait

/// "Hey Siri, what's the wait for Space Mountain?"
struct CheckWaitIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Wait Time"
    static var description = IntentDescription("Look up the current wait for an attraction.")

    @Parameter(title: "Attraction")
    var attraction: AttractionEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("What's the wait for \(\.$attraction)?")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let attraction else {
            return .result(
                value: "No attraction selected.",
                dialog: IntentDialog("Which attraction should I check?")
            )
        }

        guard let data = WaitCacheStore.loadAttraction(id: attraction.id) else {
            return .result(
                value: "No live data.",
                dialog: IntentDialog("I don't have live data for \(attraction.name) yet. Open QueueBuddy once to sync.")
            )
        }

        if !data.attraction.isOpen {
            let line = "\(data.attraction.name) is currently closed at \(data.park.name)."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }

        if let wait = data.attraction.waitMinutes {
            let line = wait == 0
                ? "\(data.attraction.name) is a walk-on right now."
                : "The wait for \(data.attraction.name) is \(wait) minute\(wait == 1 ? "" : "s")."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }

        let line = "\(data.attraction.name) is open but its wait isn't reported right now."
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
    }
}

// MARK: - Live data for intents

enum IntentWaitData {
    /// Waits for the given parks (nil = all). Uses the shared cache when it's
    /// fresh, otherwise fetches live so Siri doesn't read out an old number.
    static func digest(parkIds: Set<Int>?) async -> WaitDigest {
        let cached = WaitCacheStore.loadParks()
        let scoped = cached.filter { parkIds?.contains($0.id) ?? true }
        let isFresh = WaitCacheStore.lastSync.map { Date().timeIntervalSince($0) < 10 * 60 } ?? false
        if isFresh, !scoped.isEmpty { return WaitDigest.fromCached(scoped) }

        let parks: [(id: Int, name: String)] = scoped.isEmpty
            ? StaticData.buildResortGroups().flatMap(\.parks)
                .filter { parkIds?.contains($0.id) ?? true }
                .map { ($0.id, $0.name) }
            : scoped.map { ($0.id, $0.name) }

        let live: [Int: [Attraction]] = await withTaskGroup(of: (Int, [Attraction])?.self) { group in
            for park in parks {
                group.addTask {
                    guard let rides = try? await ThemeParkAPI.shared.fetchWaitTimes(for: park.id) else { return nil }
                    return (park.id, rides)
                }
            }
            var out: [Int: [Attraction]] = [:]
            for await result in group { if let (id, rides) = result { out[id] = rides } }
            return out
        }

        var rides: [WaitDigest.Ride] = []
        for park in parks {
            if let fresh = live[park.id] {
                rides += fresh.map {
                    WaitDigest.Ride(name: $0.name, parkId: park.id, parkName: park.name,
                                    wait: $0.wait_time, isOpen: $0.is_open ?? true)
                }
            } else if let old = scoped.first(where: { $0.id == park.id }) {
                rides += WaitDigest.fromCached([old]).rides
            }
        }
        return WaitDigest(parks: parks, rides: rides)
    }

    static func scopeName(_ digest: WaitDigest, all: Bool) -> String {
        if all { return "all parks" }
        let names = digest.parkOrder.map(\.name)
        return names.count <= 2 ? names.joined(separator: " and ") : "\(names.count) parks"
    }

    static func spoken(_ ride: WaitDigest.Ride, withPark: Bool) -> String {
        let w = ride.wait ?? 0
        let wait = w == 0 ? "a walk-on" : "\(w) minutes"
        return withPark ? "\(ride.name) at \(ride.parkName), \(wait)" : "\(ride.name), \(wait)"
    }
}

// MARK: - Intent: shortest waits

/// "What's short right now in QueueBuddy?" (every park) or "…at Epic Universe".
struct ShortestWaitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Shortest Waits"
    static var description = IntentDescription("Find the shortest open attraction waits at a park, or across every park.")

    @Parameter(title: "Park", description: "Leave empty to check every park.")
    var park: ParkEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Shortest waits at \(\.$park)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let digest = await IntentWaitData.digest(parkIds: park.map { [$0.id] })
        let scope = IntentWaitData.scopeName(digest, all: park == nil)
        let top = digest.shortest(3)
        guard !top.isEmpty else {
            let line = "No live waits for \(scope) right now. The parks may be closed."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }
        let list = top.map { IntentWaitData.spoken($0, withPark: park == nil) }.joined(separator: "; ")
        let line = "Shortest waits at \(scope): \(list)."
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
    }
}

// MARK: - Intent: longest waits

/// "What's the longest wait in QueueBuddy?"
struct LongestWaitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Longest Waits"
    static var description = IntentDescription("Find the longest attraction waits at a park, or across every park.")

    @Parameter(title: "Park", description: "Leave empty to check every park.")
    var park: ParkEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Longest waits at \(\.$park)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let digest = await IntentWaitData.digest(parkIds: park.map { [$0.id] })
        let scope = IntentWaitData.scopeName(digest, all: park == nil)
        let top = digest.longest(3)
        guard let first = top.first else {
            let line = "No live waits for \(scope) right now. The parks may be closed."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }
        let withPark = park == nil
        var line = "The longest wait at \(scope) is \(IntentWaitData.spoken(first, withPark: withPark))."
        let rest = top.dropFirst().map { IntentWaitData.spoken($0, withPark: withPark) }
        if !rest.isEmpty { line += " Then \(rest.joined(separator: "; "))." }
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
    }
}

// MARK: - Intent: ask QueueBuddy

/// "Ask QueueBuddy" → Siri asks for the question, and the answer comes from
/// the AI provider chosen in Settings, grounded on live waits for the
/// chosen parks (every park by default).
struct AskQueueBuddyIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask QueueBuddy"
    static var description = IntentDescription("Ask a question about live waits across your chosen parks. Uses the AI provider set in QueueBuddy's Settings.")

    @Parameter(title: "Question", requestValueDialog: "What do you want to know?")
    var question: String

    @Parameter(title: "Parks", description: "Leave empty to include every park.")
    var parks: [ParkEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary("Ask QueueBuddy \(\.$question)") {
            \.$parks
        }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard AIProviderRegistry.currentIsConfigured() else {
            let line = "Set up an AI provider in QueueBuddy's Settings first. You can still ask me for the longest or shortest waits."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }

        let ids = parks.flatMap { $0.isEmpty ? nil : Set($0.map(\.id)) }
        let digest = await IntentWaitData.digest(parkIds: ids)
        var context = "[Current Context]\nParks in scope: \(digest.parkOrder.map(\.name).joined(separator: ", ")). Only mention attractions from these parks, and name the park beside each one."
        context += "\n\n" + digest.factsBlock()
        if AIProviderRegistry.currentKind() != .apple {
            context += "\n\n" + digest.rosterBlock()
        }

        let system = WaitTimeViewModel.systemPrompt + """


        This answer will be SPOKEN by Siri. Reply in at most three short sentences of plain text: no lists, headings, markdown or emoji.
        """

        do {
            let reply = try await AIProviderRegistry.currentClient().complete(
                systemPrompt: system,
                contextBlock: context,
                history: [],
                userMessage: question,
                maxTokens: 300
            )
            let spoken = reply
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .result(value: spoken, dialog: IntentDialog(stringLiteral: spoken))
        } catch {
            let line = "I couldn't reach the AI right now. \((error as? LocalizedError)?.errorDescription ?? "")"
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }
    }
}

// MARK: - App Shortcut surface

struct QueueBuddyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckWaitIntent(),
            phrases: [
                "What's the wait for \(\.$attraction) in \(.applicationName)?",
                "Check \(.applicationName) for \(\.$attraction)",
                "How long is the line for \(\.$attraction) in \(.applicationName)?"
            ],
            shortTitle: "Check Wait",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: ShortestWaitsIntent(),
            phrases: [
                "Shortest waits at \(\.$park) in \(.applicationName)",
                "What's short at \(\.$park) in \(.applicationName)?",
                "What's the shortest wait in \(.applicationName)?",
                "Shortest waits in \(.applicationName)"
            ],
            shortTitle: "Shortest Waits",
            systemImageName: "arrow.down.right"
        )
        AppShortcut(
            intent: LongestWaitsIntent(),
            phrases: [
                "What's the longest wait in \(.applicationName)?",
                "Longest waits in \(.applicationName)",
                "What's the longest wait at \(\.$park) in \(.applicationName)?",
                "Longest waits at \(\.$park) in \(.applicationName)"
            ],
            shortTitle: "Longest Waits",
            systemImageName: "arrow.up.right"
        )
        AppShortcut(
            intent: AskQueueBuddyIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) a question",
                "Ask \(.applicationName) about the parks"
            ],
            shortTitle: "Ask QueueBuddy",
            systemImageName: "sparkles"
        )
    }
}
