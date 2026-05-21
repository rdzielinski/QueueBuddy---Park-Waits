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
        let fire = shouldFire(key: String(attractionId), isActive: isBelow)
        #if DEBUG
        print("🔔 dedup \(attractionId): wait=\(currentWait) ≤ \(threshold)? \(isBelow), fire=\(fire)")
        #endif
        return fire
    }

    /// Generic edge-trigger: fires once on the false→true transition of
    /// `isActive` for a given storage key. Used for status changes,
    /// Lightning Lane drops, and any future per-attraction signals.
    /// Caller picks a key that namespaces the event (e.g. "down-\(id)").
    static func shouldFire(key: String, isActive: Bool) -> Bool {
        let wasActive = currentMap()[key] ?? false
        setState(key: key, isActive: isActive)
        return isActive && !wasActive
    }

    /// True iff we've never recorded any state for this key — used by
    /// callers that want to skip the cold-start "false → true" fire on
    /// the very first sample (e.g. "this LL just became available")
    /// because there was no real prior state to transition from.
    static func hasStateRecorded(forKey key: String) -> Bool {
        currentMap()[key] != nil
    }

    /// Treat the attraction's wait-threshold as "above threshold" again
    /// — used when the ride closes or the wait becomes unknown. Closures
    /// shouldn't suppress the next legitimate alert when the ride
    /// reopens with a low wait.
    static func resetState(attractionId: Int) {
        setState(key: String(attractionId), isActive: false)
    }

    /// Forget all per-attraction state for a removed notification
    /// preference (wait-threshold, status, LL — every event kind).
    static func clear(attractionId: Int) {
        let suffix = "-\(attractionId)"
        let bareKey = String(attractionId)
        var dict = currentMap()
        dict = dict.filter { k, _ in k != bareKey && !k.hasSuffix(suffix) }
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

    private static func setState(key: String, isActive: Bool) {
        var dict = currentMap()
        dict[key] = isActive
        persist(dict)
    }

    private static func persist(_ dict: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
