import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Mirror of the type defined in `QueueBuddyWidget/ParkDayLiveActivity.swift`.
/// Both copies must keep identical names + property shapes for ActivityKit
/// to resolve the same activity across targets.
struct ParkDayAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var parkId: Int
        var parkName: String
        var parkAccentHex: UInt32
        var primaryName: String
        var primaryWait: Int?
        var primaryIsOpen: Bool
        var secondaryLines: [String]
        var updatedAt: Date
    }

    var sessionName: String
}

/// Controller for the "Park Day" Live Activity. Only one runs at a time;
/// content is sourced from `ParkDayPlanStore.shared` joined with the
/// view model's latest wait times. Local-only (no push token) — stays
/// accurate while the app is foreground or recently backgrounded, but
/// goes stale once iOS suspends us for long. Push support can be layered
/// on later by mirroring `InLineActivityController`'s push wiring.
@available(iOS 16.1, *)
@MainActor
enum ParkDayActivityController {

    private static var current: Activity<ParkDayAttributes>? {
        Activity<ParkDayAttributes>.activities.first
    }

    static var activeParkId: Int? { current?.content.state.parkId }

    static func isRunning(forParkId parkId: Int) -> Bool {
        activeParkId == parkId
    }

    /// Starts a fresh Park Day Live Activity, ending any prior one first.
    /// Returns false if the plan is empty for this park (nothing to show).
    @discardableResult
    static func start(park: Park, attractions: [Attraction]) -> Bool {
        let parkAccentHex = DB.accentHexValue(for: park.id)
        guard let state = buildState(
            parkId: park.id,
            parkName: park.name,
            parkAccentHex: parkAccentHex,
            attractions: attractions
        ) else { return false }

        if let existing = current {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }

        do {
            _ = try Activity<ParkDayAttributes>.request(
                attributes: ParkDayAttributes(sessionName: "Park Day"),
                content: .init(state: state, staleDate: Date().addingTimeInterval(60 * 60))
            )
            return true
        } catch {
            dprint("Failed to start Park Day Live Activity: \(error)")
            return false
        }
    }

    /// Rebuilds the live activity's content from the latest plan items +
    /// wait times. No-op if no Park Day activity is running. If nothing is
    /// selected anymore, ends the activity rather than showing a stale ride.
    static func refresh(attractionsByPark: [Int: [Attraction]]) {
        guard let activity = current else { return }
        let prior = activity.content.state
        let attractions = attractionsByPark[prior.parkId] ?? []
        guard let state = buildState(
            parkId: prior.parkId,
            parkName: prior.parkName,
            parkAccentHex: prior.parkAccentHex,
            attractions: attractions
        ) else {
            stop()
            return
        }
        Task {
            await activity.update(.init(
                state: state,
                staleDate: Date().addingTimeInterval(60 * 60)
            ))
        }
    }

    static func stop() {
        guard let activity = current else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - State construction

    private static func buildState(
        parkId: Int,
        parkName: String,
        parkAccentHex: UInt32,
        attractions: [Attraction]
    ) -> ParkDayAttributes.ContentState? {
        let selected = ParkDayPlanStore.shared.items(for: parkId).filter { $0.isSelected }
        guard let next = selected.first else { return nil }

        let byId = Dictionary(uniqueKeysWithValues: attractions.map { ($0.id, $0) })
        let nextLive = byId[next.attractionId]

        let upcoming = selected.dropFirst().prefix(3).map { item -> String in
            let live = byId[item.attractionId]
            let waitText: String
            if live?.is_open == false {
                waitText = "CLOSED"
            } else if let w = live?.wait_time {
                waitText = "\(w) MIN"
            } else {
                waitText = "—"
            }
            return "\(item.attractionName.uppercased()) · \(waitText)"
        }

        return ParkDayAttributes.ContentState(
            parkId: parkId,
            parkName: parkName,
            parkAccentHex: parkAccentHex,
            primaryName: next.attractionName,
            primaryWait: nextLive?.wait_time,
            primaryIsOpen: nextLive?.is_open ?? true,
            secondaryLines: Array(upcoming),
            updatedAt: Date()
        )
    }
}
#endif
