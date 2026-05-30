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
///
/// Dates travel as `Double` (UNIX seconds since 1970) rather than Swift's
/// native `Date` because the Cloudflare push worker pushes JSON updates
/// — Swift's default `Date` Codable encoding is reference-since-2001 and
/// produces a number a Worker would need to special-case. UNIX seconds
/// is the lingua franca.
struct InLineAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var attractionName: String
        var parkAccentHex: UInt32
        var currentWait: Int?
        var startedAt: Double
        var lastUpdatedAt: Double
    }

    var attractionId: Int
    var parkUUID: String
}

/// Wrapper around `Activity<InLineAttributes>` so the rest of the app
/// stays off the ActivityKit API directly. Adds remote-update support:
/// on `start`, we register with the Cloudflare worker so it can push
/// updates while the app is suspended / killed; on `stop`, we unregister
/// so the worker stops trying.
@available(iOS 16.2, *)
@MainActor
enum InLineActivityController {
    private static var current: Activity<InLineAttributes>? {
        Activity<InLineAttributes>.activities.first
    }

    /// Tasks watching the push token + activity state. Kept here so we
    /// can cancel them when the activity ends.
    private static var observerTasks: [Task<Void, Never>] = []

    static func isRunning(for attractionId: Int) -> Bool {
        current?.attributes.attractionId == attractionId
    }

    static func start(
        attractionId: Int,
        parkUUID: String,
        attractionName: String,
        parkAccentHex: UInt32,
        currentWait: Int?
    ) {
        // Only one in-line activity at a time — end any existing one
        // first (and tell the worker to stop pushing to it).
        if let existing = current {
            let oldTokenHex = existing.pushToken.map(Self.hex)
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
                if let oldTokenHex { await LiveActivityBackend.unregister(pushToken: oldTokenHex) }
            }
        }
        cancelObservers()

        let attrs = InLineAttributes(attractionId: attractionId, parkUUID: parkUUID)
        let nowSeconds = Date().timeIntervalSince1970
        let state = InLineAttributes.ContentState(
            attractionName: attractionName,
            parkAccentHex: parkAccentHex,
            currentWait: currentWait,
            startedAt: nowSeconds,
            lastUpdatedAt: nowSeconds
        )

        do {
            let activity = try Activity<InLineAttributes>.request(
                attributes: attrs,
                content: .init(
                    state: state,
                    staleDate: Date().addingTimeInterval(60 * 30)
                ),
                pushType: .token
            )
            observePushToken(for: activity)
            observeLifecycle(for: activity)
        } catch {
            dprint("Failed to start in-line Live Activity: \(error)")
        }
    }

    /// Local fallback update — still used by the app's own foreground /
    /// BG refresh code. The worker also pushes updates; both paths feed
    /// the same Activity. ActivityKit is idempotent here.
    static func update(attractionId: Int, currentWait: Int?) {
        guard let activity = current, activity.attributes.attractionId == attractionId else { return }
        var state = activity.content.state
        state.currentWait = currentWait
        state.lastUpdatedAt = Date().timeIntervalSince1970
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(60 * 30)))
        }
    }

    static func stop() {
        guard let activity = current else { return }
        let tokenHex = activity.pushToken.map(Self.hex)
        cancelObservers()
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            if let tokenHex { await LiveActivityBackend.unregister(pushToken: tokenHex) }
        }
    }

    /// APNs device tokens are exchanged as lowercase hex strings.
    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Observers

    private static func observePushToken(for activity: Activity<InLineAttributes>) {
        let task = Task {
            // `pushTokenUpdates` yields the current token on subscribe and
            // again any time iOS rotates it. We re-register on every yield
            // so the worker always has the live token.
            for await tokenData in activity.pushTokenUpdates {
                let tokenHex = Self.hex(tokenData)
                let state = activity.content.state
                await LiveActivityBackend.register(
                    attractionId: activity.attributes.attractionId,
                    parkUUID: activity.attributes.parkUUID,
                    pushToken: tokenHex,
                    activityId: activity.id,
                    attractionName: state.attractionName,
                    parkAccentHex: state.parkAccentHex,
                    startedAt: state.startedAt
                )
            }
        }
        observerTasks.append(task)
    }

    private static func observeLifecycle(for activity: Activity<InLineAttributes>) {
        let task = Task {
            for await state in activity.activityStateUpdates {
                if state == .ended || state == .dismissed || state == .stale {
                    if let token = activity.pushToken.map(Self.hex) {
                        await LiveActivityBackend.unregister(pushToken: token)
                    }
                    cancelObservers()
                    break
                }
            }
        }
        observerTasks.append(task)
    }

    private static func cancelObservers() {
        for t in observerTasks { t.cancel() }
        observerTasks.removeAll()
    }
}
#endif
