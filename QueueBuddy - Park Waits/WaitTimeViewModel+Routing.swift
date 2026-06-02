import Foundation

extension WaitTimeViewModel {

    // MARK: - Tuning knobs
    //
    // These live in UserDefaults so the BG-task path (which creates a
    // fresh WaitTimeViewModel each time) shares the same throttle clock
    // as the foreground refresh path.

    /// UserDefaults key holding the UNIX seconds of the last evaluation.
    private static let lastEvalAtKey = "RouteEvaluator.lastEvalAt"

    /// Don't pay Claude tokens more often than this. Wait times don't
    /// move fast enough on a 1-minute cadence for re-evaluating to be
    /// worth it.
    private static let minSecondsBetweenEvaluations: TimeInterval = 5 * 60

    /// UserDefaults key for the user's max wait tolerance. The Plan view
    /// can wire a slider to this later; for now we read it with a sane
    /// default so the routing engine has something to lean on.
    private static let maxWaitToleranceKey = "RouteEvaluator.maxWaitToleranceMinutes"
    private static let defaultMaxWaitTolerance = 60

    /// Cap snapshot list so the prompt doesn't blow out the token budget
    /// on a park with hundreds of low-signal pins.
    private static let maxWaitSnapshots = 40

    // MARK: - Public API

    /// Evaluate the user's plan against current waits if conditions are
    /// right. Called from `loadInitialData()` after live waits have
    /// landed, and also from foreground refresh.
    ///
    /// Silently no-ops if any precondition fails — routing is a
    /// background optimization, not a feature users get told about when
    /// it can't run.
    func evaluateRouteIfNeeded() async {
        // Don't bother building a context if the active provider isn't
        // configured (no key for cloud providers, unsupported device for
        // Apple Intelligence).
        guard AIProviderRegistry.currentIsConfigured() else { return }

        // Throttle. Use UserDefaults so BG refresh and foreground refresh
        // share the same clock across viewModel lifetimes.
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: Self.lastEvalAtKey)
        if last > 0, now - last < Self.minSecondsBetweenEvaluations {
            return
        }

        guard let (context, parkId) = buildRouteContext() else { return }

        // Mark the eval timestamp before the network call so two
        // concurrent refreshes (foreground + BG) don't both fire.
        UserDefaults.standard.set(now, forKey: Self.lastEvalAtKey)

        guard let decision = await RouteEvaluator.evaluate(context) else { return }

        await MainActor.run {
            applyRouteDecision(decision, parkId: parkId)
        }
    }

    /// Dismiss the in-app banner. Also clears the Live Activity routing
    /// line so the lock-screen card doesn't keep showing a stale message
    /// after the user has acknowledged it.
    func acknowledgeRouteDecision() {
        latestRouteDecision = nil
        latestRouteDecisionParkId = nil
        if #available(iOS 16.2, *) {
            InLineActivityController.clearRoute()
        }
    }

    // MARK: - Configuration accessors

    static func currentMaxWaitTolerance() -> Int {
        let v = UserDefaults.standard.integer(forKey: maxWaitToleranceKey)
        return v > 0 ? v : defaultMaxWaitTolerance
    }

    static func setMaxWaitTolerance(_ minutes: Int) {
        UserDefaults.standard.set(minutes, forKey: maxWaitToleranceKey)
    }

    // MARK: - Context assembly

    /// Builds the `RouteContext` if we have an actionable next plan item
    /// *and* the wait-time data needed to reason about it.
    private func buildRouteContext() -> (context: RouteContext, parkId: Int)? {
        // Walk the user's undone plan items in order. Pick the first one
        // whose park has loaded waits — that's the one the routing
        // engine can usefully reason about.
        let undone = ParkDayPlanStore.shared.items(for: nil).filter { !$0.isDone }

        for item in undone {
            let attractions = attractionsByPark[item.parkId] ?? []
            guard !attractions.isEmpty else { continue }

            let parkName = resortGroups
                .flatMap(\.parks)
                .first(where: { $0.id == item.parkId })?
                .name ?? ""

            let nextAttraction = attractions.first(where: { $0.id == item.attractionId })
            let nextName = nextAttraction?.name ?? "Attraction #\(item.attractionId)"

            let snapshots: [RouteContext.WaitSnapshot] = attractions
                .filter { $0.wait_time != nil || $0.status != nil }
                .prefix(Self.maxWaitSnapshots)
                .map { a in
                    RouteContext.WaitSnapshot(
                        name: a.name,
                        waitMinutes: a.wait_time,
                        status: a.status
                    )
                }

            let context = RouteContext(
                parkName: parkName,
                nextStepName: nextName,
                nextStepTargetTime: item.plannedDate,
                waitTimes: snapshots,
                currentLocationLabel: nil,
                maxWaitToleranceMinutes: Self.currentMaxWaitTolerance(),
                groupProfile: nil
            )
            return (context, item.parkId)
        }

        return nil
    }

    /// Apply a decision back to the view model + Live Activity.
    private func applyRouteDecision(_ decision: RouteDecision, parkId: Int) {
        // Only surface a banner if Claude actually triggered a reroute —
        // when the plan is fine the engine stays invisible.
        guard decision.rerouteTriggered else { return }

        latestRouteDecision = decision
        latestRouteDecisionParkId = parkId
        if #available(iOS 16.2, *) {
            InLineActivityController.updateRoute(
                message: decision.lockScreenMessage,
                nextDestinationName: decision.nextDestination.attractionName
            )
        }
    }
}
