import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for "I'm in line for a ride right now" — pinned to the
/// Lock Screen / Dynamic Island while the user is queued up.
///
/// Mirror of the type defined in `QueueBuddyWidget/InLineLiveActivity.swift`.
/// Both copies must keep identical names + property shapes for ActivityKit
/// to resolve the same activity across targets.
struct InLineAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var attractionName: String
        var parkAccentHex: UInt32
        var currentWait: Int?
        var startedAt: Date
        var lastUpdatedAt: Date
    }

    var attractionId: Int
}

/// Wrapper around `Activity<InLineAttributes>` so the rest of the app stays
/// off the ActivityKit API directly.
@available(iOS 16.2, *)
@MainActor
enum InLineActivityController {
    private static var current: Activity<InLineAttributes>? {
        Activity<InLineAttributes>.activities.first
    }

    static func isRunning(for attractionId: Int) -> Bool {
        current?.attributes.attractionId == attractionId
    }

    static func start(attractionId: Int, attractionName: String, parkAccentHex: UInt32, currentWait: Int?) {
        // Only one in-line activity at a time — end any existing one first.
        if let existing = current {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
        let attrs = InLineAttributes(attractionId: attractionId)
        let now = Date()
        let state = InLineAttributes.ContentState(
            attractionName: attractionName,
            parkAccentHex: parkAccentHex,
            currentWait: currentWait,
            startedAt: now,
            lastUpdatedAt: now
        )
        do {
            _ = try Activity<InLineAttributes>.request(
                attributes: attrs,
                content: .init(state: state, staleDate: now.addingTimeInterval(60 * 30)),
                pushType: nil
            )
        } catch {
            print("Failed to start in-line Live Activity: \(error)")
        }
    }

    static func update(attractionId: Int, currentWait: Int?) {
        guard let activity = current, activity.attributes.attractionId == attractionId else { return }
        var state = activity.content.state
        state.currentWait = currentWait
        state.lastUpdatedAt = Date()
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(60 * 30)))
        }
    }

    static func stop() {
        guard let activity = current else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#endif
