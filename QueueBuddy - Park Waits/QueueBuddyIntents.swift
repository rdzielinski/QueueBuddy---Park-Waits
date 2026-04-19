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

struct ParkQuery: EntityQuery {
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

// MARK: - Intent: shortest waits at a park

struct ShortestWaitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Shortest Waits in Park"
    static var description = IntentDescription("Find the shortest open attraction waits at a selected park.")

    @Parameter(title: "Park")
    var park: ParkEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Shortest waits at \(\.$park)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        guard let cached = WaitCacheStore.loadPark(id: park.id) else {
            let line = "No live data for \(park.name) yet."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }

        let open = cached.attractions
            .filter { $0.isOpen && $0.waitMinutes != nil }
            .sorted { ($0.waitMinutes ?? Int.max) < ($1.waitMinutes ?? Int.max) }
            .prefix(3)

        guard !open.isEmpty else {
            let line = "No live waits for \(cached.name) yet."
            return .result(value: line, dialog: IntentDialog(stringLiteral: line))
        }

        let list = open.map { a in
            let w = a.waitMinutes ?? 0
            return w == 0 ? "\(a.name) is a walk-on" : "\(a.name) at \(w) minutes"
        }.joined(separator: ", ")

        let line = "Shortest at \(cached.name): \(list)."
        return .result(value: line, dialog: IntentDialog(stringLiteral: line))
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
                "What's short at \(\.$park) in \(.applicationName)?"
            ],
            shortTitle: "Shortest Waits",
            systemImageName: "arrow.down.right"
        )
    }
}
