import Foundation

/// Threshold-crossing dedup for wait-time notifications.
///
/// Without this, every background refresh that sees a wait at-or-below
/// the user's threshold fires a fresh notification — so the user gets
/// pinged every 10 minutes for the same ride. We instead fire only on
/// the *transition* from "above threshold / unknown" to "at-or-below",
/// and re-arm once the wait climbs back above. Persisted to UserDefaults
/// so the state survives both app relaunches and BG-task invocations
/// (which spin up a fresh `WaitTimeViewModel`).
enum NotificationDedupStore {
    private static let storageKey = "qb.notificationDedupState.v1"

    /// Record a fresh sample for an attraction and decide whether the
    /// user should be notified. Returns true exactly once per crossing
    /// from "above threshold" to "at or below threshold".
    static func shouldFire(attractionId: Int, currentWait: Int, threshold: Int) -> Bool {
        let isBelow = currentWait <= threshold
        let wasBelow = lastBelowState(attractionId: attractionId) ?? false
        setBelowState(attractionId: attractionId, isBelow: isBelow)
        return isBelow && !wasBelow
    }

    /// Treat the attraction as "above threshold" again — used when the
    /// ride closes or wait becomes unknown. Closures shouldn't suppress
    /// the next legitimate alert when the ride reopens with a low wait.
    static func resetState(attractionId: Int) {
        setBelowState(attractionId: attractionId, isBelow: false)
    }

    /// Forget a removed notification preference so we don't keep stale
    /// per-attraction state forever.
    static func clear(attractionId: Int) {
        var dict = currentMap()
        dict.removeValue(forKey: String(attractionId))
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    // MARK: - Private

    private static func currentMap() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
    }

    private static func lastBelowState(attractionId: Int) -> Bool? {
        currentMap()[String(attractionId)]
    }

    private static func setBelowState(attractionId: Int, isBelow: Bool) {
        var dict = currentMap()
        dict[String(attractionId)] = isBelow
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}
