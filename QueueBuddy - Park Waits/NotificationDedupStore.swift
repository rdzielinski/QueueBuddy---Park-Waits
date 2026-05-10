import Foundation

/// Threshold-crossing dedup for wait-time notifications.
///
/// Without this, every refresh that sees a wait at-or-below the user's
/// threshold fires a fresh notification — so the user gets pinged every
/// pull-to-refresh and every BG tick. We instead fire only on the
/// *transition* from "above threshold / unknown" to "at-or-below", and
/// re-arm once the wait climbs back above. State is persisted as a JSON
/// blob in UserDefaults so it survives app relaunches and BG-task
/// invocations (which spin up a fresh `WaitTimeViewModel`).
///
/// We deliberately don't use `UserDefaults.dictionary(forKey:)` for the
/// roundtrip — Bool values get stored as `__NSCFBoolean`, and the
/// `[String: Any] as? [String: Bool]` cast on read silently falls back
/// to `[:]`. That looked like "everything is unseen" to the dedup, which
/// re-fired notifications every refresh. JSON encoding is bulletproof.
enum NotificationDedupStore {
    private static let storageKey = "qb.notificationDedupState.v2"

    /// Record a fresh sample for an attraction and decide whether the
    /// user should be notified. Returns true exactly once per crossing
    /// from "above threshold" to "at or below threshold".
    static func shouldFire(attractionId: Int, currentWait: Int, threshold: Int) -> Bool {
        let isBelow = currentWait <= threshold
        let wasBelow = lastBelowState(attractionId: attractionId) ?? false
        setBelowState(attractionId: attractionId, isBelow: isBelow)
        let fire = isBelow && !wasBelow
        #if DEBUG
        print("🔔 dedup \(attractionId): wait=\(currentWait) ≤ \(threshold)? \(isBelow), wasBelow=\(wasBelow), fire=\(fire)")
        #endif
        return fire
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
        persist(dict)
    }

    // MARK: - Private

    private static func currentMap() -> [String: Bool] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func lastBelowState(attractionId: Int) -> Bool? {
        currentMap()[String(attractionId)]
    }

    private static func setBelowState(attractionId: Int, isBelow: Bool) {
        var dict = currentMap()
        dict[String(attractionId)] = isBelow
        persist(dict)
    }

    private static func persist(_ dict: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
